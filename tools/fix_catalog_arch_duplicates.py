#!/usr/bin/env python3
"""
Fix duplicated catalog entries that only differ by architecture prefix (amd64/arm64).

Usage:
  python3 tools/fix_catalog_arch_duplicates.py catalog/apps.json

The script will rewrite the file, merging entries that share the same id/name and
the same script path after removing a leading architecture directory. Merged
entries will keep the original `script` (prefer `amd64` when available) and
add `architectures` (list) and `script_paths` (map arch->path).
"""
import json
import sys
from collections import OrderedDict


def detect_arch(script_path):
    if not isinstance(script_path, str):
        return None, script_path
    parts = script_path.split('/', 1)
    if len(parts) == 2 and parts[0] in ('amd64', 'arm64'):
        return parts[0], parts[1]
    return None, script_path


def main(argv):
    if len(argv) < 2:
        print('Usage: fix_catalog_arch_duplicates.py <catalog/apps.json>')
        return 2
    path = argv[1]
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    apps = data.get('apps', [])
    groups = OrderedDict()

    for app in apps:
        script = app.get('script')
        arch, stripped = detect_arch(script)
        # key by id if available, otherwise by name lower + stripped script
        if app.get('id'):
            key = (app.get('id'), stripped)
        else:
            key = (app.get('name', '').lower(), stripped)

        g = groups.get(key)
        if not g:
            g = {
                'representative': dict(app),
                'scripts_by_arch': {},
                'arch_set': set()
            }
            groups[key] = g

        if arch:
            g['scripts_by_arch'][arch] = script
            g['arch_set'].add(arch)
        else:
            # treat as generic (no arch)
            g['scripts_by_arch']['generic'] = script

        # Merge fields conservatively: prefer non-empty values and longer descriptions
        rep = g['representative']
        for k, v in app.items():
            if k == 'script':
                continue
            if not rep.get(k) and v:
                rep[k] = v
            elif isinstance(v, str) and isinstance(rep.get(k, ''), str):
                if len(v) > len(rep.get(k, '')):
                    rep[k] = v

    merged = []
    for (key, stripped), g in groups.items():
        rep = g['representative']
        scripts = g['scripts_by_arch']
        archs = sorted([a for a in scripts.keys() if a != 'generic'])

        # If there is a generic script, keep it as-is and note no architectures
        if 'generic' in scripts and not archs:
            rep['architectures'] = []
            rep['script_paths'] = {'generic': scripts['generic']}
            merged.append(rep)
            continue

        # prefer amd64 as canonical script when available
        canonical = scripts.get('amd64') or next(iter(scripts.values()))
        rep['script'] = canonical
        rep['architectures'] = archs
        rep['script_paths'] = scripts
        merged.append(rep)

    out = {'apps': merged}
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'Wrote {len(merged)} apps to {path}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
