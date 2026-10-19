#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile
import zipfile

if (platform.system(), platform.machine()) != ('Linux', 'x86_64'):
    raise SystemExit('This bootstrap targets Linux x86_64. For Mac/Windows, use the pinned upstream releases linked in README.md.')
root = Path('.tools')
(root / 'cache').mkdir(parents=True, exist_ok=True)
(root / 'bin').mkdir(exist_ok=True)
for asset in json.loads(Path('tools.json').read_text())['assets']:
    archive = root / 'cache' / asset['name']
    if not archive.exists():
        fd, partial = tempfile.mkstemp(dir=root / 'cache')
        os.close(fd)
        try:
            subprocess.run(['curl', '--fail', '--location', '--retry', '2', '--connect-timeout', '15', '--max-time', '120', '--proto', '=https', '--proto-redir', '=https', '--silent', '--show-error', asset['url'], '--output', partial], check=True)
            if hashlib.sha256(Path(partial).read_bytes()).hexdigest() != asset['sha256']:
                raise SystemExit('Upstream checksum verification failed: ' + asset['name'])
            os.replace(partial, archive)
        finally:
            Path(partial).unlink(missing_ok=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != asset['sha256']:
        raise SystemExit('Cached checksum verification failed: ' + str(archive))
    with zipfile.ZipFile(archive) as package:
        for name in asset['executables']:
            target = root / 'bin' / name
            target.write_bytes(package.read(name))
            target.chmod(0o755)
    print('Verified and installed ' + asset['name'])
PY
