"""Run deterministic game-rule tests and build the actual Roblox place."""
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

for tool in ('rojo', 'luau', 'luau-analyze', 'luau-compile'):
    if not shutil.which(tool):
        raise SystemExit('Missing ' + tool + '. Run bash scripts/bootstrap.sh first.')

pure = sorted(Path('src/shared').glob('*.luau')) + sorted(Path('tests').glob('*.luau')) + sorted(Path('scripts').glob('*.luau'))
subprocess.run(['luau-analyze', *(str(p) for p in pure)], check=True)
for suite in sorted(Path('tests').glob('*.spec.luau')):
    subprocess.run(['luau', str(suite)], check=True)
subprocess.run(['python3', 'scripts/map_assets.py'], check=True)

sources = sorted(Path('src').rglob('*.luau'))
for path in sources:
    subprocess.run(['luau-compile', '--binary', str(path)], stdout=subprocess.DEVNULL, check=True)
print(f'Compiled {len(sources)} game scripts', flush=True)

Path('build').mkdir(exist_ok=True)
place = Path('build/ZosArk.rbxlx')
subprocess.run(['rojo', 'build', 'default.project.json', '--output', str(place)], check=True)
tree = ET.parse(place)
embedded = tree.findall(".//Item[@class='Script']") + tree.findall(".//Item[@class='LocalScript']") + tree.findall(".//Item[@class='ModuleScript']")
assert len(embedded) == len(sources), 'The place must contain every game script'
for item in embedded:
    source = item.find("./Properties/*[@name='Source']")
    assert source is not None and source.text and len(source.text) > 20
assert len(tree.findall(".//Item[@class='LocalScript']")) == 1, 'Expected the player interface LocalScript'
assert len(tree.findall(".//Item[@class='Script']")) == 1, 'Expected the server bootstrap Script'
print(f'Place verified: {place} ({place.stat().st_size:,} bytes, {len(embedded)} scripts)')
print('Studio playtesting, DataStore integration and multiplayer checks remain manual; see docs/TESTING.md.')
