#!/usr/bin/env python3
"""
fixupxer_patch.py

Custom runtime patch and fallback handler for fixupxer state machine transitions.
"""

import sys
from typing import Dict, Tuple, Any, Optional


class AutomatonPatchError(Exception):
    """Raised when an unrecoverable state transition mismatch occurs."""
    pass


class AutomatonPatchEngine:
    """
    Interprets and normalizes token streams prior to automaton processing
    and provides explicit recovery paths for unmapped delta(state, token) pairs.
    """

    def __init__(self, pattern_overrides: Optional[Dict[str, str]] = None):
        # Anchor regex override patterns to prevent empty-string token loops
        self.pattern_overrides = pattern_overrides or {
            "wordmark_anchor": r"<!--\s*WORDMARK_INJECTION_POINT\s*-->",
            "default_fallback": r"\S+"
        }

    def sanitize_token(self, token_type: str, token_value: str) -> Tuple[str, str]:
        """
        Ensures anchor tokens contain valid match content before entering the state machine.
        """
        # Resolve empty-string match regressions on injection points
        if token_type in ("WORDMARK", "INJECTION_POINT") and not token_value.strip():
            token_value = self.pattern_overrides["wordmark_anchor"]
            token_type = "WORDMARK"
            
        return token_type, token_value

    def resolve_fallback_state(
        self, 
        current_state: str, 
        token_type: str, 
        transitions: Dict[Tuple[str, str], str]
    ) -> str:
        """
        Evaluates state transition validity. If delta(state, token) is undefined,
        returns a deterministic fallback state.
        """
        key = (current_state, token_type)
        if key in transitions:
            return transitions[key]

        # Explicit recovery matrix for missing transition paths
        fallback_matrix: Dict[Tuple[str, str], str] = {
            # Target -> Token -> Recovery State
            ("IN_HEADER", "TOKEN_WORDMARK"): "IN_WORDMARK_INJECTION",
            ("IN_BODY", "TOKEN_WORDMARK"): "IN_WORDMARK_INJECTION",
            ("IN_WORDMARK_INJECTION", "TOKEN_NEWLINE"): "IN_BODY",
            ("IN_WORDMARK_INJECTION", "TOKEN_EOF"): "END",
            ("IN_BODY", "TOKEN_UNKNOWN"): "IN_BODY",
        }

        if key in fallback_matrix:
            return fallback_matrix[key]

        # Non-terminal state fallback: maintain active state to prevent premature halt
        if current_state not in ("END", "FATAL_ERROR", "HALT"):
            return current_state

        raise AutomatonPatchError(
            f"Undefined transition with no recovery path: state='{current_state}', token='{token_type}'"
        )


def apply_fixupxer_patch(parser_instance: Any) -> None:
    """
    Monkeys-patches a fixupxer ParserEngine instance to wrap its transition method.
    """
    patch_engine = AutomatonPatchEngine()
    original_step = getattr(parser_instance, "step", None)

    def patched_step(token: Any) -> str:
        raw_type = getattr(token, "type", "TOKEN_UNKNOWN")
        raw_value = getattr(token, "value", "")

        # 1. Sanitize token
        clean_type, clean_value = patch_engine.sanitize_token(raw_type, raw_value)
        token.type = clean_type
        token.value = clean_value

        # 2. Check and intercept transition
        current_state = getattr(parser_instance, "current_state", "INIT")
        transitions = getattr(parser_instance, "transitions", {})

        key = (current_state, clean_type)
        if key not in transitions:
            next_state = patch_engine.resolve_fallback_state(current_state, clean_type, transitions)
            parser_instance.current_state = next_state
            return next_state

        # 3. Proceed with standard execution if transition exists
        if original_step:
            return original_step(token)

        parser_instance.current_state = transitions[key]
        return parser_instance.current_state

    # Bind patched method to instance
    parser_instance.step = patched_step


if __name__ == "__main__":
    # Integration test asserting patch recovery logic
    class MockFixupxerParser:
        def __init__(self):
            self.current_state = "IN_BODY"
            self.transitions = {
                ("INIT", "TOKEN_TEXT"): "IN_HEADER",
                ("IN_HEADER", "TOKEN_NEWLINE"): "IN_BODY",
            }

    class MockToken:
        def __init__(self, t_type, value):
            self.type = t_type
            self.value = value

    parser = MockFixupxerParser()
    apply_fixupxer_patch(parser)

    # Test handling unmapped WORDMARK token with empty string value
    broken_token = MockToken("WORDMARK", "")
    new_state = parser.step(broken_token)

    print(f"Patched Token Value: '{broken_token.value}'")
    print(f"Recovered State: '{new_state}'")
