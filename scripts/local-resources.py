#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json, plistlib, sys
from pathlib import Path
app, build = map(Path, sys.argv[1:])
root = Path(__file__).resolve().parents[1]
group = 'group.local.westtime'
for name, target, executable, identifier in [
    ('App', app, 'WEST', 'local.westtime.app'),
    ('Widget', app/'Contents/PlugIns/WESTWidgets.appex', 'WESTWidgets', 'local.westtime.app.widgets')]:
    info = plistlib.loads((root/f'Config/{name}-Info.plist').read_bytes())
    info.update(CFBundleExecutable=executable, CFBundleIdentifier=identifier,
                CFBundleName='WEST time and timer' if name=='App' else 'WESTWidgets',
                WESTAppGroup=group, WESTUseLocalSharedStorage='YES')
    (target/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    if name == 'App':
        (target/'Contents/Resources/AppIcon.icns').write_bytes((root/'WEST/Resources/AppIcon.icns').read_bytes())
    catalog = json.loads((root/'WEST/Resources/Localizable.xcstrings').read_text())
    for language in info['CFBundleLocalizations']:
        directory = target/'Contents/Resources'/f'{language}.lproj'
        directory.mkdir(parents=True, exist_ok=True)
        values = {key: entry['localizations'][language]['stringUnit']['value'] for key, entry in catalog['strings'].items()}
        lines = [json.dumps(k, ensure_ascii=False)+' = '+json.dumps(v, ensure_ascii=False)+';' for k,v in values.items()]
        (directory/'Localizable.strings').write_text('\n'.join(lines)+'\n')
entitlements = plistlib.loads((root/'Config/Local-AdHoc.entitlements').read_bytes())
(build/'local.entitlements').write_bytes(plistlib.dumps(entitlements))
