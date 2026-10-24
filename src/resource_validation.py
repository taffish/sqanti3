#!/usr/bin/env python3
"""Validate immutable, explicitly selected SQANTI3 evidence resources."""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

SCHEMA = 'taffish.sqanti3.resource.v1'
ROOT_SCHEMA = 'taffish.sqanti3.resource-root.v1'
KINDS = {'cage-bed', 'polya-bed', 'polya-motifs', 'phylop-bed', 'isoannot-gff3', 'junctions-star'}


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def spec_check(spec):
    required = {'schema', 'id', 'version', 'kind', 'assembly', 'url', 'sha256',
                'bytes', 'license', 'license_url', 'filename'}
    if set(spec) != required or spec['schema'] != SCHEMA:
        raise ValueError('invalid resource descriptor schema/fields')
    for key in ('id', 'version', 'filename'):
        if not isinstance(spec[key], str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,119}', spec[key]):
            raise ValueError('unsafe resource ' + key)
    if spec['filename'] in {'manifest.json', 'READY'}:
        raise ValueError('reserved resource filename')
    if spec['kind'] not in KINDS:
        raise ValueError('unsupported resource kind')
    for key in ('assembly', 'license', 'license_url', 'url'):
        if not isinstance(spec[key], str) or not spec[key].strip() or any(ord(c) < 32 for c in spec[key]):
            raise ValueError('missing/invalid resource ' + key)
    if not re.fullmatch(r'[0-9a-f]{64}', spec['sha256']):
        raise ValueError('SHA256 must be 64 lowercase hexadecimal characters')
    if type(spec['bytes']) is not int or spec['bytes'] < 1:
        raise ValueError('resource bytes must be positive')
    from urllib.parse import urlsplit
    for key in ('url', 'license_url'):
        uri = urlsplit(spec[key])
        if uri.scheme not in {'https', 'http'} or not uri.hostname or uri.username or uri.password or uri.fragment:
            raise ValueError('URL must be public HTTP(S), without credentials/fragments')
    return spec


def plain_file(path):
    mode = path.lstat().st_mode
    if not stat.S_ISREG(mode) or not mode & stat.S_IROTH or mode & 0o022:
        raise ValueError('resource must be a world-readable regular file, not writable by other users: ' + str(path))


def readable_dir(path):
    mode = path.lstat().st_mode
    if not stat.S_ISDIR(mode) or mode & 5 != 5 or mode & 0o022:
        raise ValueError('resource directory must be publicly readable/traversable, not writable by other users: ' + str(path))


def format_check(path, kind):
    count = 0
    with path.open(encoding='utf-8') as stream:
        for line_number, line in enumerate(stream, 1):
            text = line.strip()
            if not text or text.startswith(('#', 'track ', 'browser ')):
                continue
            fields = text.split('\t')
            if kind == 'polya-motifs':
                valid = re.fullmatch('[ACGTRYKMSWBDHVNacgtrykmswbdhvn]+', text) is not None
            elif kind == 'isoannot-gff3':
                # tappAS explicitly permits non-positional gene annotations.
                valid = len(fields) == 9 and all(v == '.' or v.isdigit() for v in fields[3:5])
                if valid and fields[2] in {'exon', 'CDS', 'protein'}:
                    valid = all(v.isdigit() for v in fields[3:5])
            elif kind == 'junctions-star':
                valid = len(fields) == 9 and all(value.isdigit() for value in fields[1:])
            else:
                valid = len(fields) >= (4 if kind == 'phylop-bed' else 6)
                valid = valid and fields[1].isdigit() and fields[2].isdigit() and int(fields[1]) < int(fields[2])
                if valid and kind != 'phylop-bed':
                    valid = fields[5] in {'+', '-'}
                if valid and kind == 'phylop-bed':
                    try:
                        import math
                        valid = math.isfinite(float(fields[3]))
                    except ValueError:
                        valid = False
            if not valid:
                raise ValueError(f'invalid {kind} record at line {line_number}')
            count += 1
    if not count:
        raise ValueError('empty resource')


def member_check(member, expected=None):
    readable_dir(member)
    for name in ('manifest.json', 'READY'):
        plain_file(member / name)
    spec = spec_check(json.loads((member / 'manifest.json').read_text()))
    if expected is not None and spec != expected:
        raise ValueError('existing member identity differs; use a new version, never overwrite')
    if member.name != spec['version'] or member.parent.name != spec['id']:
        raise ValueError('member directory/manifest identity mismatch')
    if (member / 'READY').read_text().strip() != digest(member / 'manifest.json'):
        raise ValueError('READY/manifest mismatch')
    if {p.name for p in member.iterdir()} != {'manifest.json', 'READY', spec['filename']}:
        raise ValueError('unexpected or missing member entries')
    payload = member / spec['filename']
    plain_file(payload)
    if payload.stat().st_size != spec['bytes'] or digest(payload) != spec['sha256']:
        raise ValueError('resource size/SHA256 mismatch')
    format_check(payload, spec['kind'])
    return spec


def root_check(root, *, allow_initial=False):
    """Validate every published member; installers may also resume initialization."""
    root = Path(root).resolve(strict=True)
    if not root.is_dir() or root.stat().st_mode & 0o022:
        raise ValueError('resource root must be a directory, not writable by other users')
    marker = root / 'ROOT.json'
    if allow_initial and not marker.exists() and not marker.is_symlink():
        # Before ROOT.json is linked, only locks and atomic-write temporaries
        # can legitimately exist. Never recreate a lost identity over a store.
        for entry in root.iterdir():
            mode = entry.lstat().st_mode
            initial_lock = entry.name == '.locks' and stat.S_ISDIR(mode)
            atomic_file = entry.name.startswith('.taffish-json-') and stat.S_ISREG(mode)
            if not (initial_lock or atomic_file) or mode & 0o022:
                raise ValueError('missing ROOT.json in a nonempty resource store; restore its verified identity')
        return []
    plain_file(marker)
    if json.loads(marker.read_text()) != {'schema': ROOT_SCHEMA, 'app': 'sqanti3'}:
        raise ValueError('wrong root identity')
    members = root / 'members'
    if allow_initial and not members.exists() and not members.is_symlink():
        if (root / '.partial').exists() or (root / '.partial').is_symlink():
            raise ValueError('missing members directory in an initialized resource store')
        return []
    readable_dir(members)
    records = []
    for group in sorted(members.iterdir()):
        readable_dir(group)
        for member in sorted(group.iterdir()):
            records.append(member_check(member))
    if records or not allow_initial:
        readable_dir(root)
    if not records and not allow_initial:
        raise ValueError('resource root has no complete selected member')
    return records


if __name__ == '__main__':
    try:
        records = root_check(sys.argv[1])
        print(f'sqanti3-resources: verified {len(records)} member(s)', file=sys.stderr)
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        print('sqanti3-resources: ' + str(exc), file=sys.stderr)
        raise SystemExit(64)
