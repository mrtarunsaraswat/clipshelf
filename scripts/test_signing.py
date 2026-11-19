"""Signing validation checks using fictional profile data; no credentials or network."""
import datetime
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('icloud_entitlements.py')
GROUP = 'group.example.clipshelf'
BUNDLE = 'example.clipshelf'
TEAM = 'EXAMPLETEAM'


class SigningChecks(unittest.TestCase):
    def derive(self, change=None, *, container='', role='host', group=GROUP, bundle=BUNDLE):
        allowed = {
            'com.apple.application-identifier': TEAM + '.' + BUNDLE,
            'com.apple.developer.team-identifier': TEAM,
            'com.apple.security.application-groups': [GROUP],
            'com.apple.developer.icloud-container-identifiers': ['iCloud.example.clipshelf'],
            'com.apple.developer.icloud-services': ['CloudKit'],
            'com.apple.developer.icloud-container-environment': 'Production',
        }
        profile = {'Entitlements': allowed, 'ExpirationDate': datetime.datetime.now() + datetime.timedelta(days=1)}
        if change:
            change(profile)
        with tempfile.TemporaryDirectory(prefix='clipshelf-signing-') as directory:
            source, output = Path(directory) / 'profile.plist', Path(directory) / 'output.plist'
            source.write_bytes(plistlib.dumps(profile))
            result = subprocess.run([sys.executable, str(SCRIPT), str(source), container, bundle, str(output), group, role], capture_output=True, text=True)
            return result.returncode, plistlib.loads(output.read_bytes()) if output.exists() else None

    def test_host_cloud_and_group(self):
        code, value = self.derive(container='iCloud.example.clipshelf')
        self.assertEqual(code, 0)
        self.assertFalse(value['com.apple.security.app-sandbox'])
        self.assertEqual(value['com.apple.security.application-groups'], [GROUP])
        self.assertEqual(value['com.apple.developer.icloud-container-environment'], 'Production')

    def test_widget_does_not_inherit_cloud_entitlements(self):
        code, value = self.derive(role='widget')
        self.assertEqual(code, 0)
        self.assertTrue(value['com.apple.security.app-sandbox'])
        self.assertNotIn('com.apple.developer.icloud-services', value)

    def test_reject_unauthorized_group(self):
        self.assertNotEqual(self.derive(group='group.other')[0], 0)

    def test_reject_wrong_bundle(self):
        self.assertNotEqual(self.derive(bundle='example.other')[0], 0)

    def test_reject_expired_profile(self):
        self.assertNotEqual(self.derive(lambda p: p.update(ExpirationDate=datetime.datetime(2000, 1, 1)))[0], 0)

    def test_reject_debugging_profile(self):
        self.assertNotEqual(self.derive(lambda p: p['Entitlements'].update({'get-task-allow': True}))[0], 0)

    def test_reject_cloud_development_environment(self):
        self.assertNotEqual(self.derive(lambda p: p['Entitlements'].update({'com.apple.developer.icloud-container-environment': 'Development'}), container='iCloud.example.clipshelf')[0], 0)


class LocalSigningChecks(unittest.TestCase):
    def generate(self, team="ABCDE12345", group=None):
        group = group or team + '.clipshelf'
        with tempfile.TemporaryDirectory(prefix='clipshelf-local-signing-') as folder:
            result = subprocess.run([sys.executable, str(SCRIPT.with_name('local_widget_entitlements.py')), team, group, folder], capture_output=True, text=True)
            return result.returncode, {p.stem: plistlib.loads(p.read_bytes()) for p in Path(folder).glob('*.entitlements')}

    def test_local_team_group_requires_no_cloud_or_debug_release_access(self):
        code, values = self.generate()
        self.assertEqual(code, 0)
        self.assertFalse(values['host']['com.apple.security.app-sandbox'])
        self.assertTrue(values['widget']['com.apple.security.app-sandbox'])
        for role in ('host', 'widget'):
            self.assertEqual(values[role]['com.apple.security.application-groups'], ['ABCDE12345.clipshelf'])
            self.assertNotIn('com.apple.developer.icloud-services', values[role])
            self.assertNotIn('get-task-allow', values[role])
            self.assertNotIn('com.apple.security.cs.allow-jit', values[role])
        self.assertTrue(values['host-debug']['com.apple.security.cs.allow-jit'])

    def test_local_signing_rejects_another_teams_group(self):
        self.assertNotEqual(self.generate(group='OTHER12345.clipshelf')[0], 0)

    def test_local_signing_rejects_profile_required_group(self):
        self.assertNotEqual(self.generate(group='group.example.clipshelf')[0], 0)

    def test_local_signing_rejects_invalid_team(self):
        self.assertNotEqual(self.generate(team='invalid')[0], 0)


if __name__ == '__main__':
    unittest.main()
