#!/usr/bin/env python3
import sys
sys.path.insert(0, '/home/droid/fixupxer-resilience')

from fixupxer import RuleLoader

rules = [
    {'pattern_id': 'social_trackers', 'match_pattern': 'facebook.com', 'strip_params': ['fbclid', 'utm_source', 'utm_medium']},
    {'pattern_id': 'ad_platforms', 'match_pattern': 'google.com', 'strip_params': ['gclid', 'gclsrc', 'utm_campaign']},
    {'pattern_id': 'email_clients', 'match_pattern': 'gmail.com', 'strip_params': ['ved', 'ei', 'ust']},
]

loader = RuleLoader(rules)

for line in sys.stdin:
    raw_url = line.strip()
    if raw_url:
        cleaned = loader.clean(raw_url)
        sys.stdout.write(f"{cleaned}\n")
