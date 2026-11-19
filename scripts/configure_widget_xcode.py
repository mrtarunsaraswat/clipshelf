"""Configure an ignored local Xcode signing override for macOS widget testing.

Usage: TEAM_ID [APP_GROUP]
The ignored config contains public identifiers only; certificates/private keys stay in Keychain.
"""
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
team = sys.argv[1]
group = sys.argv[2] if len(sys.argv) > 2 else team + '.clipshelf'
output = root / 'macos' / 'Runner' / 'Configs' / 'LocalWidgetSigning'
subprocess.run([sys.executable, str(root / 'scripts/local_widget_entitlements.py'), team, group, str(output)], check=True)
config = root / 'macos' / 'Runner' / 'Configs' / 'LocalWidgetSigning.xcconfig'
config.write_text('''// Generated for this Mac; excluded from source control.
DEVELOPMENT_TEAM = ''' + team + '''
CLIPSHELF_SIGNING_STYLE = Manual
CODE_SIGN_IDENTITY = Apple Development
CODE_SIGN_IDENTITY[sdk=macosx*] = Apple Development
CLIPSHELF_APP_GROUP_ID = ''' + group + '''
CLIPSHELF_HOST_DEBUG_ENTITLEMENTS = Runner/Configs/LocalWidgetSigning/host-debug.entitlements
CLIPSHELF_HOST_PROFILE_ENTITLEMENTS = Runner/Configs/LocalWidgetSigning/host-debug.entitlements
CLIPSHELF_HOST_RELEASE_ENTITLEMENTS = Runner/Configs/LocalWidgetSigning/host.entitlements
CLIPSHELF_WIDGET_ENTITLEMENTS = Runner/Configs/LocalWidgetSigning/widget.entitlements
''')
print('Configured local widget signing for ' + team + '; private keys remain in Keychain.')
