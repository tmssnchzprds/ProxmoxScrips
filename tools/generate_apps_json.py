#!/usr/bin/env python3
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / 'cache' / 'apps_catalog.txt'
OUTPUT = ROOT / 'catalog' / 'apps.json'
BACKUP = ROOT / 'catalog' / 'apps.json.bak'

def make_id(name):
    # normalize: lower, remove extension and common suffixes
    name = re.sub(r"\.sh$", "", name, flags=re.I)
    name = re.sub(r"[-_](install|setup)$", "", name, flags=re.I)
    name = name.lower()
    name = re.sub(r"[^a-z0-9\-]+", "-", name)
    name = re.sub(r"-+", "-", name).strip('-')
    return name

def human_name(idv):
    return idv.replace('-', ' ').title()

apps = {}

if not INPUT.exists():
    print(f"Input file not found: {INPUT}")
    raise SystemExit(1)

with INPUT.open('r', encoding='utf-8') as f:
    for raw in f:
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if '|' not in line:
            continue
        cat, path = line.split('|', 1)
        cat = cat.strip()
        path = path.strip()
        # derive arch if first path component looks like arch
        parts = path.split('/')
        arch = parts[0] if parts and parts[0] in ('amd64', 'arm64') else None
        filename = os.path.basename(path)
        idv = make_id(os.path.splitext(filename)[0])
        name = human_name(idv)
        desc = ''
        if 'install' in cat or 'install' in path.lower():
            desc = f"Instalador para {name}."
        # merge or create
        if idv not in apps:
            apps[idv] = {
                'id': idv,
                'name': name,
                'category': cat,
                'description': desc,
                'template': '',
                'resources': {'memory': 1024, 'cores': 1},
                'icon': '',
                'script': path,
                'architectures': [],
                'script_paths': {}
            }
        # ensure script default if missing
        if not apps[idv].get('script'):
            apps[idv]['script'] = path
        if arch:
            if arch not in apps[idv]['architectures']:
                apps[idv]['architectures'].append(arch)
            apps[idv]['script_paths'][arch] = path
        else:
            # if no arch, keep generic script only
            apps[idv]['script'] = path

# convert to list
apps_list = list(apps.values())

# backup existing
if OUTPUT.exists():
    try:
        BACKUP.write_bytes(OUTPUT.read_bytes())
        print(f"Backup written to {BACKUP}")
    except Exception as e:
        print(f"Warning: could not write backup: {e}")

payload = {'apps': apps_list}
with OUTPUT.open('w', encoding='utf-8') as out:
    json.dump(payload, out, ensure_ascii=False, indent=2)

print(f"Wrote {len(apps_list)} apps to {OUTPUT}")
