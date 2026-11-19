"""Generate local-only macOS Team-ID App Group entitlements; no credentials.

Usage: TEAM_ID APP_GROUP output-directory
These intentionally do not add CloudKit, a profile-required group.*, or debug access.
"""
import plistlib
import re
import sys
from pathlib import Path

team, group, output = sys.argv[1:]
if not re.fullmatch(r'[A-Z0-9]{10}', team):
    raise SystemExit('Use the 10-character Team ID shown by Xcode.')
if not group.startswith(team + '.') or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', group[len(team) + 1:]):
    raise SystemExit('Use a macOS App Group beginning with your signing Team ID followed by a dot and a group name.')
folder = Path(output)
folder.mkdir(parents=True, exist_ok=True)
for role in ('host', 'host-debug', 'widget'):
    data = {
        'com.apple.security.app-sandbox': role == 'widget',
        'com.apple.security.application-groups': [group],
    }
    if role == 'host-debug':
        data.update({'com.apple.security.cs.allow-jit': True, 'com.apple.security.network.server': True})
    (folder / (role + '.entitlements')).write_bytes(plistlib.dumps(data))
