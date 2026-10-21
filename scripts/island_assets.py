"""Verify the two traced islands and generate an overview from game geometry."""
from collections import deque
import html
import json
import math
from pathlib import Path
from map_assets import load_map, contains, distance

def to_world(plan, x, y):
    s = plan['Source']
    return (x-s['pivotX'])*s['scale']+s.get('offsetX',0), (y-s['pivotY'])*s['scale']+s.get('offsetZ',0)

def check_islands(data):
    checks = 0
    def check(ok, message):
        nonlocal checks
        if not ok:
            raise AssertionError(message)
        checks += 1
    check(len(data['islands']) == 2, 'Both additional image layouts are required')
    plans = [data, *data['islands']]
    def water(wx, wz, margin=0):
        for item in plans:
            plan = item['layout']; s = plan['Source']
            x = (wx-s.get('offsetX',0))/s['scale']+s['pivotX']
            y = (wz-s.get('offsetZ',0))/s['scale']+s['pivotY']
            if any(r[0]-margin/s['scale'] <= x <= r[2]+margin/s['scale'] and r[1]-margin/s['scale'] <= y <= r[3]+margin/s['scale'] for r in item['floorTiles']):
                return False
        return True
    for item in data['islands']:
        plan, walls, tiles = item['layout'], item['walls'], item['floorTiles']
        name, s = plan['Name'], plan['Source']
        check(s['scale'] > 0, name+' scale must retain north/east orientation')
        check(plan['SeabedY'] < plan['WaterY'] < plan['FloorY'], name+' foundation must reach the seabed')
        check(len({r['id'] for r in plan['Rooms']}) == len(plan['Rooms']), name+' duplicate room ID')
        check(len(plan['Checkpoints']) == 3, name+' needs three checkpoints')
        for zone in plan['Zones']:
            marine = zone['habitat'] in ('reef','ocean')
            r=zone['rect']; x,y=(r[0]+r[2])/2,(r[1]+r[3])/2
            wx,wz=to_world(plan,x,y)
            check(water(wx,wz)==marine, name+'/'+zone['id']+' has incorrect ground/water')
            check(min(r[2]-r[0], r[3]-r[1])*s['scale'] > 14, name+' habitat too narrow')
        # The same footprint/wall data feeds Roblox. Expand a 3-stud avatar
        # against walls and verify walkable doors, galleries and side rooms.
        step=3
        x0,y0,x1,y1=plan['Bounds']
        nx,ny=math.ceil((x1-x0)/step)+1, math.ceil((y1-y0)/step)+1
        blocked=set()
        for row in range(ny):
            for col in range(nx):
                x,y=x0+col*step,y0+row*step
                if not any(contains(r,x,y) for r in tiles): blocked.add((col,row))
        radius=(1.5+plan['WallThickness']/2)/s['scale']
        for wall in walls:
            left,right=min(wall[0],wall[2])-radius,max(wall[0],wall[2])+radius
            top,bottom=min(wall[1],wall[3])-radius,max(wall[1],wall[3])+radius
            for row in range(max(0,math.floor((top-y0)/step)),min(ny,math.ceil((bottom-y0)/step)+1)):
                for col in range(max(0,math.floor((left-x0)/step)),min(nx,math.ceil((right-x0)/step)+1)):
                    if distance(x0+col*step,y0+row*step,wall)<=radius: blocked.add((col,row))
        def cell(x,y): return round((x-x0)/step),round((y-y0)/step)
        start=cell(plan['Checkpoints'][0]['x'],plan['Checkpoints'][0]['y'])
        check(start not in blocked,name+' landing checkpoint is blocked')
        reached={start}; queue=deque([start])
        while queue:
            col,row=queue.popleft()
            for nxt in ((col-1,row),(col+1,row),(col,row-1),(col,row+1)):
                a,b=nxt
                if 0<=a<nx and 0<=b<ny and nxt not in blocked and nxt not in reached:
                    reached.add(nxt); queue.append(nxt)
        for room in plan['Rooms']:
            if 'rect' in room:
                r=room['rect']; x,y=(r[0]+r[2])/2,(r[1]+r[3])/2
            else:
                p=room['polygon']; x,y=sum(v[0] for v in p)/len(p),sum(v[1] for v in p)/len(p)
            check(cell(x,y) in reached,name+' unreachable room: '+room['id'])
        for marker in [*plan['Checkpoints'],*plan['Chests']]:
            check(cell(marker['x'],marker['y']) in reached,name+' unreachable marker: '+marker['id'])
        for exit in plan['ShoreExits']:
            x,y,dx,dy=exit['x'],exit['y'],exit['dx'],exit['dy']
            check(cell(x-dx*10,y-dy*10) in reached,name+' shore exit unreachable')
            wx,wz=to_world(plan,x+dx*50,y+dy*50)
            check(water(wx,wz),name+' shore stairs do not reach water')
    # Check actual sea corridors, with an expanded boat hull, between all three
    # landings. Landing props and physical boarding remain Studio checks.
    gate=to_world(data['layout'],*data['layout']['SeaGate'])
    for item in data['islands']:
        plan=item['layout']; dock=plan['Dock']
        x,z=to_world(plan,dock['x'],dock['y'])
        destination=(x+dock['dx']*60,z+dock['dy']*60)
        route=[gate,(650,gate[1]),(650,destination[1]),destination]
        for a,b in zip(route,route[1:]):
            samples=max(1,math.ceil(math.dist(a,b)/5))
            for i in range(samples+1):
                x=a[0]+(b[0]-a[0])*i/samples; z=a[1]+(b[1]-a[1])*i/samples
                check(water(x,z,10),plan['Name']+' boat route crosses a shore')
    for i,a in enumerate(plans):
        for b in plans[i+1:]:
            for tile in a['floorTiles']:
                x,z=to_world(a['layout'],(tile[0]+tile[2])/2,(tile[1]+tile[3])/2)
                bs=b['layout']['Source']; bx=(x-bs.get('offsetX',0))/bs['scale']+bs['pivotX']; by=(z-bs.get('offsetZ',0))/bs['scale']+bs['pivotY']
                check(not any(contains(t,bx,by) for t in b['floorTiles']),'Island footprints overlap')
    print(f'Archipelago structural checks passed: {checks}; both islands, rooms, checkpoints, chests and sea corridors reachable')

def render(data):
    out=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-620 -1120 2300 2200" role="img" aria-label="Zo\'s Ark three-island gameplay layout">',
         '<rect x="-620" y="-1120" width="2300" height="2200" fill="#163f50"/>',
         '<g font-family="DejaVu Sans,Arial,sans-serif"><text x="-560" y="-1030" font-size="55" fill="#f2e2ba" font-weight="bold">ZO’S ARK / THREE ISLANDS</text>']
    colors={'room':'#c7cfb5','jungle':'#598f6b','meadow':'#9bbf7c','summit':'#ccdce0','entry':'#e4c78c','atrium':'#d4ae70'}
    for item in [data,*data['islands']]:
        plan=item['layout']
        def rect(r,fill):
            x,z=to_world(plan,r[0],r[1]); x2,z2=to_world(plan,r[2],r[3])
            out.append(f'<rect x="{x}" y="{z}" width="{x2-x}" height="{z2-z}" fill="{fill}"/>')
        for tile in item['floorTiles']: rect(tile,'#6d8d74')
        for room in plan['Rooms']:
            if room['kind']=='marine': continue
            tint=colors.get(room['kind'],colors['room'])
            if 'rect' in room: rect(room['rect'],tint)
            else:
                pts=' '.join(f'{x},{z}' for x,z in [to_world(plan,*p) for p in room['polygon']])
                out.append(f'<polygon points="{pts}" fill="{tint}"/>')
        for wall in item['walls']:
            x,z=to_world(plan,*wall[:2]); x2,z2=to_world(plan,*wall[2:])
            out.append(f'<path d="M{x},{z} L{x2},{z2}" stroke="#263e3c" stroke-width="2"/>')
        for cp in plan['Checkpoints']:
            x,z=to_world(plan,cp['x'],cp['y'])
            out.append(f'<circle cx="{x}" cy="{z}" r="8" fill="#ffe3a0"/>')
        x,z=to_world(plan,plan['Bounds'][0],plan['Bounds'][1])
        out.append(f'<text x="{x}" y="{z-24}" fill="#f3e5bd" font-size="31" font-weight="bold">{html.escape(plan.get("Name","Ark Sanctuary"))}</text>')
    out.append('<path d="M399,-268.8 H650 V476.9 H749 M650,-268.8 V-497.1 H731" stroke="#b8e5d1" stroke-width="5" stroke-dasharray="12 10" fill="none"/>')
    out.append('<text x="80" y="-550" fill="#e6d5aa" font-size="31">N ↑</text><text x="-560" y="970" fill="#ecdcb7" font-size="27">Approximate traces from all three user-supplied floor plans. North-up; gameplay scale.</text>')
    out.append('<text x="-560" y="1020" fill="#b5d7c9" font-size="25">Dots: checkpoints. Dashed lines: sea routes. Hidden animals and chests require exploration.</text></g></svg>')
    target=Path('docs/archipelago-layout.svg'); target.write_text('\n'.join(out)+'\n')
    print('Archipelago review diagram:',target)

if __name__=='__main__':
    data=load_map(); check_islands(data); render(data)
    Path('build/archipelago-layout.json').write_text(json.dumps(data,indent=2)+'\n')
