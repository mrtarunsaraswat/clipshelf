"""Derive least-privilege host/extension entitlements from a distribution profile.

Usage: profile.plist container-or-empty bundle-id output [app-group] [host|widget]
"""
import datetime
import plistlib
import sys
from pathlib import Path

profile_path, container, bundle_id, output, *options = sys.argv[1:]
group = options[0] if options else ''
role = options[1] if len(options) > 1 else 'host'
if role not in ('host', 'widget'):
    raise SystemExit('Unknown signing role.')
profile = plistlib.loads(Path(profile_path).read_bytes())
allowed = profile['Entitlements']
if profile.get('ExpirationDate', datetime.datetime.min) <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
    raise SystemExit('The provisioning profile has expired.')
app_id = allowed.get('com.apple.application-identifier', allowed.get('application-identifier', ''))
team = allowed.get('com.apple.developer.team-identifier', '')
if not team or app_id != team + '.' + bundle_id or '*' in app_id:
    raise SystemExit('Use an explicit distribution profile matching this bundle identifier and team.')
if allowed.get('get-task-allow', allowed.get('com.apple.security.get-task-allow', False)):
    raise SystemExit('Use a distribution profile, not a development profile.')
result = {
    'com.apple.security.app-sandbox': role == 'widget',
    'com.apple.application-identifier': app_id,
    'com.apple.developer.team-identifier': team,
}
if container:
    if role != 'host' or container not in allowed.get('com.apple.developer.icloud-container-identifiers', []):
        raise SystemExit('The host profile must authorize this iCloud container.')
    if 'CloudKit' not in allowed.get('com.apple.developer.icloud-services', []):
        raise SystemExit('The profile must authorize CloudKit.')
    environment = allowed.get('com.apple.developer.icloud-container-environment')
    if environment != 'Production' and not (isinstance(environment, list) and 'Production' in environment):
        raise SystemExit('The profile must authorize Production iCloud.')
    result.update({
        'com.apple.developer.icloud-container-identifiers': [container],
        'com.apple.developer.icloud-services': ['CloudKit'],
        'com.apple.developer.icloud-container-environment': 'Production',
    })
if group:
    if group not in allowed.get('com.apple.security.application-groups', []):
        raise SystemExit('The profile does not authorize the shared App Group.')
    result['com.apple.security.application-groups'] = [group]
Path(output).write_bytes(plistlib.dumps(result))
