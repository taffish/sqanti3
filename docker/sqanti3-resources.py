#!/usr/bin/env python3
"""Explicit, checksum-pinned single-file evidence installation; never select biology."""
import argparse
from contextlib import contextmanager
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile
import urllib.request

from resource_validation import ROOT_SCHEMA, digest, format_check, member_check, root_check, spec_check


def write_atomic(path, content):
    descriptor, temporary = tempfile.mkstemp(prefix='.taffish-json-', dir=path.parent)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            stream.write(content)
            stream.flush()
            os.fchmod(stream.fileno(), 0o644)
            os.fsync(stream.fileno())
        os.link(temporary, path)  # Exclusive, atomic visibility; never overwrite.
    finally:
        os.unlink(temporary)


def write_json(path, obj):
    write_atomic(path, json.dumps(obj, indent=2, sort_keys=True) + '\n')


def fail_signal(number, frame):
    print(f'sqanti3-resources: interrupted by signal {number}; partial retained; published members unchanged', file=sys.stderr)
    raise SystemExit(128 + number)


def real_dir(path, mode=0o755):
    if path.is_symlink():
        raise ValueError('installation paths must not be symlinks: ' + str(path))
    try:
        path.mkdir(mode=mode)
    except FileExistsError:
        pass
    else:
        path.chmod(mode)  # Preserve the sharing contract even under umask 077.
    if not path.is_dir():
        raise ValueError('not a directory: ' + str(path))


@contextmanager
def member_lock(path):
    # Atomic mkdir also works on host shares that silently ignore advisory locks.
    # Never infer staleness from a PID: other containers have different PID spaces.
    signals = {signal.SIGINT, signal.SIGTERM, signal.SIGHUP}
    previous = signal.pthread_sigmask(signal.SIG_BLOCK, signals)
    identity = None
    try:
        try:
            path.mkdir(mode=0o700)
        except FileExistsError:
            raise ValueError('another installer holds this member lock: ' + str(path)
                             + '; after an uncatchable interruption, confirm all installers '
                             'have stopped before removing this empty lock directory with rmdir')
        owned = path.stat(follow_symlinks=False)
        identity = (owned.st_dev, owned.st_ino)
        # A pending signal is delivered only after cleanup ownership is recorded.
        signal.pthread_sigmask(signal.SIG_SETMASK, previous)
        yield
    finally:
        signal.pthread_sigmask(signal.SIG_BLOCK, signals)
        try:
            if identity is not None:
                current = path.stat(follow_symlinks=False)
                if path.is_symlink() or (current.st_dev, current.st_ino) != identity:
                    raise ValueError('member lock ownership changed; leaving it untouched: ' + str(path))
                path.rmdir()  # Only our empty directory; never recursively delete.
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous)


def promote_no_replace(source, target):
    libc = ctypes.CDLL(None, use_errno=True)
    rename = getattr(libc, 'renameat2', None)
    if rename is None:
        raise RuntimeError('atomic no-replace rename requires Linux renameat2')
    if rename(-100, os.fsencode(source), -100, os.fsencode(target), 1):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(target))
    descriptor = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def install(args):
    spec = spec_check(json.loads(args.spec.read_text()))
    root = args.root.absolute()
    if root.is_symlink():
        raise ValueError('install root must be a real directory; resolve the alias explicitly')
    if not root.is_dir() or not os.access(root, os.W_OK | os.X_OK):
        raise ValueError('pre-create a writable install root and bind it explicitly')
    # New members and dry-runs obey the same complete-store contract as readers.
    root_check(root, allow_initial=True)
    marker = root / 'ROOT.json'
    expected_root = {'schema': ROOT_SCHEMA, 'app': 'sqanti3'}
    member = root / 'members' / spec['id'] / spec['version']
    if member.exists() or member.is_symlink():
        root_check(root)
        member_check(member, spec)
        print('sqanti3-resources: already verified ' + str(member))
        return
    if args.dry_run:
        print(json.dumps({'action': 'install', 'descriptor': spec, 'destination': str(member),
                          'minimum_free_bytes': spec['bytes'] + 16 * 1024**2,
                          'network': args.local_file is None, 'license_acceptance_required': True}, indent=2))
        return
    if not args.accept_license:
        raise ValueError('review the independent resource license, then explicitly pass --accept-license')
    if args.local_file is None and not args.allow_download:
        raise ValueError('network disabled by default; use --local-file or explicitly --allow-download')
    real_dir(root / '.locks', 0o700)
    lock_name = hashlib.sha256((spec['id'] + '\0' + spec['version']).encode()).hexdigest()
    with member_lock(root / '.locks' / lock_name):
        root_check(root, allow_initial=True)
        if member.exists() or member.is_symlink():
            root_check(root)
            member_check(member, spec)
            print('sqanti3-resources: already verified ' + str(member))
            return
        if not marker.exists():
            # Exclusive creation is safe for concurrent installers of different members.
            try:
                write_json(marker, expected_root)
            except FileExistsError:
                root_check(root, allow_initial=True)
        real_dir(root / 'members')
        real_dir(root / 'members' / spec['id'])
        real_dir(root / '.partial', 0o700)
        real_dir(root / '.partial' / spec['id'], 0o700)
        stage = root / '.partial' / spec['id'] / spec['version']
        real_dir(stage, 0o700)
        metadata = stage / 'manifest.json'
        if metadata.exists() or metadata.is_symlink():
            if metadata.is_symlink() or json.loads(metadata.read_text()) != spec:
                raise ValueError('partial identity differs; preserve it and use another version/root')
        else:
            write_json(metadata, spec)
        payload = stage / spec['filename']
        if payload.is_symlink() or (payload.exists() and not payload.is_file()):
            raise ValueError('invalid partial payload type')
        offset = payload.stat().st_size if payload.exists() else 0
        if args.restart:
            offset = 0
        if offset > spec['bytes']:
            raise ValueError('oversized partial; use --restart to reset only this uncommitted payload')
        needed = spec['bytes'] - offset + 16 * 1024**2
        if shutil.disk_usage(root).free < needed:
            raise ValueError(f'insufficient free space: need at least {needed} bytes')
        print(f'sqanti3-resources: transfer {spec["id"]}/{spec["version"]} at byte {offset}; old members untouched', flush=True)
        if offset < spec['bytes'] or args.restart:
            if args.local_file is not None:
                if not args.local_file.is_file() or args.local_file.stat().st_size != spec['bytes']:
                    raise ValueError('local source size differs from descriptor')
                incoming = args.local_file.open('rb')
                incoming.seek(offset)
            else:
                headers = {'Accept-Encoding': 'identity', 'User-Agent': 'taffish-sqanti3-resources/1'}
                if offset:
                    headers['Range'] = f'bytes={offset}-'
                incoming = urllib.request.urlopen(urllib.request.Request(spec['url'], headers=headers), timeout=30)
                if incoming.status == 206:
                    if incoming.headers.get('Content-Range') != f'bytes {offset}-{spec["bytes"]-1}/{spec["bytes"]}':
                        incoming.close()
                        raise ValueError('invalid HTTP resume range; partial preserved')
                elif incoming.status == 200:
                    offset = 0
                else:
                    incoming.close()
                    raise ValueError('unsupported HTTP response')
            with incoming:
                flags = os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW
                flags |= os.O_APPEND if offset else os.O_TRUNC
                descriptor = os.open(payload, flags, 0o600)
                with os.fdopen(descriptor, 'ab' if offset else 'wb') as outgoing:
                    written = offset
                    while True:
                        block = incoming.read(1024 * 1024)
                        if not block:
                            break
                        written += len(block)
                        if written > spec['bytes']:
                            raise ValueError('download exceeds declared size; partial preserved')
                        outgoing.write(block)
                    outgoing.flush()
                    os.fsync(outgoing.fileno())
        if payload.stat().st_size != spec['bytes'] or digest(payload) != spec['sha256']:
            raise ValueError('partial size/SHA256 mismatch; retry to resume or use --restart for corrupt bytes')
        format_check(payload, spec['kind'])
        payload.chmod(0o644)
        ready = stage / 'READY'
        if ready.is_symlink():
            raise ValueError('symlink READY is forbidden')
        if ready.exists():
            if ready.read_text().strip() != digest(metadata):
                raise ValueError('invalid partial READY')
        else:
            write_atomic(ready, digest(metadata) + '\n')
        stage.chmod(0o755)
        member_check(stage, spec)
        # Recheck after a possibly long transfer, before making anything visible.
        root_check(root, allow_initial=True)
        promote_no_replace(stage, member)
        root.chmod(root.stat().st_mode | 0o055)
        root_check(root)
        print('sqanti3-resources: installed and verified ' + str(member), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    inst = sub.add_parser('install', help='install one explicit plain-text member, with no implicit network')
    inst.add_argument('--root', type=Path, default=Path('/resource-install'))
    inst.add_argument('--spec', type=Path, required=True)
    inst.add_argument('--local-file', type=Path)
    inst.add_argument('--allow-download', action='store_true')
    inst.add_argument('--accept-license', action='store_true')
    inst.add_argument('--restart', action='store_true', help='reset this uncommitted partial only, never an installed member')
    inst.add_argument('--dry-run', action='store_true')
    for command in ('verify', 'list', 'path'):
        p = sub.add_parser(command)
        p.add_argument('--root', type=Path, default=Path('/sqanti3-resources'))
        if command == 'path':
            p.add_argument('--id', required=True)
            p.add_argument('--version', required=True)
    args = parser.parse_args()
    for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(number, fail_signal)
    if args.command == 'install':
        install(args)
    else:
        members = root_check(args.root)
        if args.command == 'path':
            selected = [m for m in members if m['id'] == args.id and m['version'] == args.version]
            if len(selected) != 1:
                raise ValueError('selected member not installed')
            print(args.root / 'members' / args.id / args.version / selected[0]['filename'])
        else:
            print(json.dumps({'verified_members': members}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('sqanti3-resources: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
