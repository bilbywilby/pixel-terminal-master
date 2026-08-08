#!/usr/bin/env python3
"""
git_push_main.py - Automates git add, commit, and push to main branch.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def run_cmd(cmd, cwd=None, check=True, quiet=False):
    """Execute shell command and handle error checking."""
    try:
        result = subprocess.run(cmd, cwd=cwd, text=True,
                                capture_output=True, check=check)
        if result.stdout.strip() and not quiet:
            print(result.stdout.strip())
        return result
    except subprocess.CalledProcessError as e:
        if not quiet:
            print(f"Error executing {' '.join(cmd)}:\n{e.stderr.strip()}", file=sys.stderr)
        if check:
            sys.exit(e.returncode)
        return e


def ensure_git_repo(repo_dir):
    """Verify repository existence and ensure main branch."""
    if not (repo_dir / ".git").is_dir():
        print(f"Error: {repo_dir} is not a git repository.", file=sys.stderr)
        sys.exit(1)

    res = run_cmd(["git", "branch", "--show-current"], cwd=repo_dir, check=False, quiet=True)
    current_branch = res.stdout.strip()

    if current_branch == "master":
        print("Renaming local branch 'master' to 'main'...")
        run_cmd(["git", "branch", "-m", "master", "main"], cwd=repo_dir)
    elif not current_branch:
        print("Creating initial 'main' branch...")
        run_cmd(["git", "checkout", "-b", "main"], cwd=repo_dir)
    elif current_branch != "main":
        print(f"Switching to 'main' branch from '{current_branch}'...")
        run_cmd(["git", "checkout", "main"], cwd=repo_dir, check=False)


def setup_remote(repo_dir, remote_url):
    """Check or configure the 'origin' remote URL."""
    res = run_cmd(["git", "remote", "get-url", "origin"], cwd=repo_dir, check=False, quiet=True)

    if res.returncode != 0:
        if not remote_url:
            print("Error: No 'origin' remote configured and no --remote-url provided.", file=sys.stderr)
            sys.exit(1)
        print(f"Setting remote 'origin' to {remote_url}...")
        run_cmd(["git", "remote", "add", "origin", remote_url], cwd=repo_dir)
    elif remote_url:
        print(f"Updating remote 'origin' URL to {remote_url}...")
        run_cmd(["git", "remote", "set-url", "origin", remote_url], cwd=repo_dir)


def commit_and_push(repo_dir, commit_msg, set_upstream=True, dry_run=False):
    """Stage all changes, commit, and push to remote main."""
    if dry_run:
        print("[DRY RUN] Would stage all changes and push.")
        return

    print("Staging modified and untracked files...")
    run_cmd(["git", "add", "-A"], cwd=repo_dir)

    status = run_cmd(["git", "status", "--porcelain"], cwd=repo_dir, quiet=True)
    if not status.stdout.strip():
        print("No changes detected to commit.")
        return

    print(f"Creating commit: '{commit_msg}'")
    run_cmd(["git", "commit", "-m", commit_msg], cwd=repo_dir)

    print("Pushing to origin/main...")
    push_args = ["git", "push"]
    if set_upstream:
        push_args.extend(["-u", "origin", "main"])
    else:
        push_args.extend(["origin", "main"])

    push_res = run_cmd(push_args, cwd=repo_dir, check=False)
    if push_res.returncode != 0:
        print("Push failed. Attempting pull --rebase before pushing...")
        pull_res = run_cmd(["git", "pull", "--rebase", "origin", "main"], cwd=repo_dir, check=False)
        if pull_res.returncode != 0:
            print("Pull --rebase failed. Resolve conflicts manually then push.")
            sys.exit(pull_res.returncode)
        run_cmd(push_args, cwd=repo_dir)

    print("Successfully committed and pushed to 'main'.")


def main():
    parser = argparse.ArgumentParser(description="Stage, commit, and push to main via Python.")
    parser.add_argument("-m", "--message", default="chore: sync repository state",
                        help="Commit message text")
    parser.add_argument("-r", "--repo",
                        default=os.path.expanduser("~/pixel-terminal-master"),
                        help="Target git repository path")
    parser.add_argument("--remote-url", default=None,
                        help="Git remote origin URL (required if origin does not exist)")
    parser.add_argument("--dry-run", action="store_true", help="Preview without executing")
    parser.add_argument("--no-push", action="store_true", help="Commit only, skip push")

    args = parser.parse_args()
    repo_path = Path(args.repo).resolve()

    print(f"Working directory: {repo_path}")
    ensure_git_repo(repo_path)
    if not args.no_push:
        setup_remote(repo_path, args.remote_url)
    commit_and_push(repo_path, args.message,
                    set_upstream=not args.no_push, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
