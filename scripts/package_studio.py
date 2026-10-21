"""Package the validated source for Studio; run scripts/check.sh first."""
from pathlib import Path
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
local_rojo = root / '.tools/bin/rojo'
rojo = str(local_rojo) if local_rojo.is_file() else shutil.which('rojo')
if not rojo:
    raise SystemExit('Rojo is missing. Run bash scripts/bootstrap.sh first.')
build, downloads = root / 'build', root / 'downloads'
build.mkdir(exist_ok=True)
downloads.mkdir(exist_ok=True)
binary = downloads / 'ZosArk-ThreeIslands.rbxl'
xml = build / 'ZosArk.rbxlx'
for target in (binary, xml):
    subprocess.run([rojo, 'build', 'default.project.json', '--output', str(target)], cwd=root, check=True)
data = binary.read_bytes()
assert data.startswith(b'<roblox!'), 'Expected an actual Roblox binary place'
# Keep earlier chat/download links working as aliases of the current game.
(downloads / 'ZosArk-Map1.rbxl').write_bytes(data)
(build / 'ZosArk-Map1.rbxl').write_bytes(data)
instructions = downloads / 'OPEN_IN_STUDIO.txt'
archive = build / 'ZosArk-ThreeIslands.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    package.write(binary, binary.name)
    package.write(xml, xml.name)
    package.write(instructions, instructions.name)
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert package.read(binary.name) == data
shutil.copyfile(archive, build / 'ZosArk-Map1.zip')
shutil.copyfile(instructions, build / instructions.name)
print(f'Studio package verified: {binary.relative_to(root)} ({len(data):,} bytes); legacy links refreshed.')
