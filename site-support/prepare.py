#!/usr/bin/env python3
"""Add only Ripple's copy/assets to the separately checked-out shared support site."""
import json
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SITE = ROOT / '.sites-checkout'
PROJECT = 'appgprj_6adb646a51b88191ba130a159bdda2d4'
assert json.loads((SITE / '.openai/hosting.json').read_text())['project_id'] == PROJECT
source = ROOT / 'ripple-pages.json'
app = json.loads(source.read_text())
for copy in app['locales'].values():
    copy['termsEffectiveLabel'] = copy['effectiveLabel']
target = SITE / 'content/apps.json'
catalog = json.loads(target.read_text())
catalog['apps'] = [old for old in catalog['apps'] if old['id'] != app['id']] + [app]
target.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')

icons = SITE / 'content/icons/ripple'
icons.mkdir(exist_ok=True)
original = ROOT.parent / 'App/Resources/Assets.xcassets/AppIcon.appiconset/Icon-light.png'
for name, size in [('favicon-16.png', 16), ('favicon-32.png', 32),
                   ('apple-touch-icon.png', 180), ('android-chrome-192.png', 192),
                   ('android-chrome-512.png', 512)]:
    subprocess.run(['/usr/bin/sips', '-z', str(size), str(size), str(original),
                    '--out', str(icons / name)], check=True, capture_output=True)
png = (icons / 'favicon-32.png').read_bytes()
(icons / 'favicon.ico').write_bytes(struct.pack('<HHH', 0, 1, 1)
    + struct.pack('<BBBBHHII', 32, 32, 0, 0, 1, 32, len(png), 22) + png)
(icons / 'site.webmanifest').write_text(json.dumps({
    'name': 'Ripple', 'short_name': 'Ripple', 'start_url': '/ripple/',
    'display': 'standalone', 'background_color': '#F4F5FA', 'theme_color': '#3B4BCC',
    'icons': [{'src': '/assets/icons/ripple/' + name, 'sizes': str(size)+'x'+str(size),
               'type': 'image/png'} for name, size in
              [('android-chrome-192.png', 192), ('android-chrome-512.png', 512)]]
}, indent=2) + '\n')
print('Prepared Ripple support copy and icons for the existing shared site.')
