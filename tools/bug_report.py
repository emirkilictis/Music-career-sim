#!/usr/bin/env python3
# Reads a bug report or a backup file (.mcsave, docs K219, K307): prints
# the player's report and writes the career's database (and images) next
# to it, so it can be opened or restored.
#   python3 tools/bug_report.py "bug-report Nova.mcsave" [out-dir]
import gzip, os, struct, sys

def entries(path):
    raw = gzip.open(path, 'rb').read()
    if raw[:4] != b'MCS1':
        sys.exit('Not a career backup')
    at = 4
    while at < len(raw):
        (n,) = struct.unpack('>H', raw[at:at + 2]); at += 2
        name = raw[at:at + n].decode('utf-8'); at += n
        (size,) = struct.unpack('>I', raw[at:at + 4]); at += 4
        yield name, raw[at:at + size]
        at += size

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__ or 'usage: bug_report.py FILE [OUT]')
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0]
    os.makedirs(out, exist_ok=True)
    report = None
    for name, data in entries(src):
        if name == 'report.txt':
            report = data.decode('utf-8', 'replace')
        target = os.path.join(out, name.replace('/', '_'))
        with open(target, 'wb') as f:
            f.write(data)
    print(report or '(no report: a plain backup)')
    print(f'\nFiles in {out}/ (career.sqlite opens with any SQLite viewer;')
    print('the .mcsave itself restores in the game: Restore a backup).')

main()
