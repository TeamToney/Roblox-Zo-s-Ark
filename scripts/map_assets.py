"""Export the actual Luau map data and draw its gameplay adaptation as an SVG."""
from collections import deque
import html
import json
import math
from pathlib import Path
import subprocess

def load_map():
    result = subprocess.run(["luau", "scripts/export_map.luau"], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)

def contains(rect, x, y):
    return rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]

def distance(x, y, wall):
    ax, ay, bx, by = wall
    dx, dy = bx - ax, by - ay
    t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - ax - t * dx, y - ay - t * dy)

def check_layout(data):
    layout, walls, floors = data["layout"], data["walls"], data["floorTiles"]
    source = layout["Source"]
    cuts = layout["WaterCuts"]
    bounds = layout["Bounds"]
    checks = 0
    def check(condition, description):
        nonlocal checks
        if not condition:
            raise AssertionError(description)
        checks += 1
    check(source["width"] == 1530 and source["height"] == 1632, "Source image orientation must be retained")
    check(len({r["id"] for r in layout["Rooms"]}) == len(layout["Rooms"]), "Room IDs must be unique")
    check(len({z["id"] for z in layout["Zones"]}) == len(layout["Zones"]), "Zone IDs must be unique")
    check({z["habitat"] for z in layout["Zones"]} == {"meadow", "jungle", "summit", "reef", "ocean"}, "Every animal habitat must be present")
    for room in layout["Rooms"]:
        points = room.get("polygon") or [[room["rect"][0], room["rect"][1]], [room["rect"][2], room["rect"][3]]]
        check(all(contains(bounds, *p) for p in points), "Room outside source parcel: " + room["id"])
        check(all(d["width"] * source["scale"] >= 12 for d in room["doors"]), "Door too narrow: " + room["id"])
        check(all(math.hypot((p[0]-source["pivotX"])*source["scale"], (p[1]-source["pivotY"])*source["scale"]) < data["travelRadius"] for p in points), "Room outside travel boundary: " + room["id"])
    for tile in floors:
        x, y = (tile[0] + tile[2]) / 2, (tile[1] + tile[3]) / 2
        check(not any(contains(c, x, y) for c in cuts), "A foundation tile blocks the lagoon or sea gate")
    for zone in layout["Zones"]:
        rect = zone["rect"]
        check(rect[2] > rect[0] and rect[3] > rect[1], "Invalid zone size: " + zone["id"])
        marine = zone["habitat"] in ("reef", "ocean")
        corners = [(rect[0], rect[1]), (rect[2], rect[1]), (rect[0], rect[3]), (rect[2], rect[3])]
        check(all((not contains(bounds, x, y) or any(contains(c, x, y) for c in cuts)) == marine for x, y in corners), "Habitat has the wrong ground/water type: " + zone["id"])
        if zone["habitat"] == "ocean":
            check(min(rect[2] - rect[0], rect[3] - rect[1]) * source["scale"] > 2 * 4.5 * 3.2, "Ocean zone cannot fit a whale: " + zone["id"])
    for boat in layout["Boats"]:
        check(any(contains(c, *boat) for c in cuts), "Boat must start in water")
        check(not contains(layout["SwimSteps"], *boat), "Boat must not spawn on the swim steps")
    # Walk-only structural reachability. A 3-stud-wide player is expanded against
    # the same wall segments used by the builder. Decorative props and vertical
    # physics are intentionally left to the Studio playtest.
    step = 4
    radius = 1.5 / source["scale"] + layout["WallThickness"] / (2 * source["scale"])
    x0, y0, x1, y1 = bounds
    nx, ny = math.ceil((x1 - x0) / step), math.ceil((y1 - y0) / step)
    blocked = set()
    for cut in cuts:
        for row in range(max(0, math.floor((cut[1] - y0) / step)), min(ny, math.ceil((cut[3] - y0) / step) + 1)):
            for col in range(max(0, math.floor((cut[0] - x0) / step)), min(nx, math.ceil((cut[2] - x0) / step) + 1)):
                if contains(cut, x0 + col * step, y0 + row * step):
                    blocked.add((col, row))
    for wall in walls:
        left, right = min(wall[0], wall[2]) - radius, max(wall[0], wall[2]) + radius
        top, bottom = min(wall[1], wall[3]) - radius, max(wall[1], wall[3]) + radius
        for row in range(max(0, math.floor((top - y0) / step)), min(ny, math.ceil((bottom - y0) / step) + 1)):
            for col in range(max(0, math.floor((left - x0) / step)), min(nx, math.ceil((right - x0) / step) + 1)):
                if distance(x0 + col * step, y0 + row * step, wall) <= radius:
                    blocked.add((col, row))
    def cell(point):
        return round((point[0] - x0) / step), round((point[1] - y0) / step)
    start = cell(layout["Spawn"])
    check(start not in blocked, "Entrance spawn must be walkable")
    reached, queue = {start}, deque([start])
    while queue:
        col, row = queue.popleft()
        for next_cell in ((col + 1, row), (col - 1, row), (col, row + 1), (col, row - 1)):
            a, b = next_cell
            if 0 <= a < nx and 0 <= b < ny and next_cell not in blocked and next_cell not in reached:
                reached.add(next_cell)
                queue.append(next_cell)
    check(cell(layout["Hub"]) in reached, "Spawn cannot reach Ark Atrium through its north entrance")
    for room in layout["Rooms"]:
        if room["kind"] == "marine":
            continue
        if "rect" in room:
            rect = room["rect"]
            center = ((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2)
        else:
            center = layout["Hub"]
        check(cell(center) in reached, "Unreachable room: " + room["id"])
    for zone in layout["Zones"]:
        if zone["habitat"] not in ("reef", "ocean"):
            r = zone["rect"]
            check(cell(((r[0] + r[2]) / 2, (r[1] + r[3]) / 2)) in reached, "Unreachable outdoor habitat: " + zone["id"])
    check(cell((1123, 394)) in reached, "Marine hall's western walkway must be reachable")
    check(cell((1210, 560)) in reached, "Southern dock approach must be reachable")
    # A boat hull plus margin must have an unobstructed, connected water route
    # from its dock through the sea gate to the added open-sea habitat.
    boat_start = (layout["Boats"][1][0], layout["Boats"][1][1])
    gate = layout["SeaGate"]
    route = [boat_start, (1215, 387), gate, (1600, 387)]
    for a, b in zip(route, route[1:]):
        samples = math.ceil(math.dist(a, b) / 2)
        for i in range(samples + 1):
            x = a[0] + (b[0] - a[0]) * i / samples
            y = a[1] + (b[1] - a[1]) * i / samples
            # Conservative circular clearance for the 10x16 stud hull.
            clearance = math.hypot(5, 8) / source["scale"]
            check(all(distance(x, y, w) > clearance for w in walls), "Boat route intersects a wall")
            check(all(not contains(bounds, px, py) or any(contains(c, px, py) for c in cuts) for px, py in [(x, y), (x-15, y), (x+15, y), (x, y-15), (x, y+15)]), "Boat hull route crosses dry ground")
    print(f"Map structural checks passed: {checks}; {len(layout['Rooms'])} rooms; {len(layout['Zones'])} habitats; all room centers reachable")
    return checks

def render_svg(data):
    layout = data["layout"]
    colors = {"room": "#dce4db", "meadow": "#9ec67d", "jungle": "#57977b", "summit": "#dcebf1", "atrium": "#e8bd7e", "entry": "#f2dba7", "marine": "#3d94a6"}
    # Source-plan proportions are preserved, with the sea extension to the right.
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -120 1940 1880" role="img" aria-label="Zo’s Ark hybrid sanctuary traced from Map 1">']
    out.append('<rect x="0" y="-120" width="1940" height="1880" fill="#102e3b"/>')
    out.append('<g font-family="DejaVu Sans, Arial, sans-serif"><text x="65" y="-55" fill="#f8efd7" font-size="38" font-weight="bold">ZO’S ARK  /  MAP 1</text><text x="65" y="-10" fill="#a8d8cb" font-size="21">Floor-plan paths + outdoor habitats + marine lagoons + open sea</text>')
    def rect(r, fill, extra=""):
        out.append(f'<rect x="{r[0]}" y="{r[1]}" width="{r[2]-r[0]}" height="{r[3]-r[1]}" fill="{fill}" {extra}/>')
    for tile in data["floorTiles"]:
        rect(tile, "#738f76")
    for r in layout["Corridors"]:
        rect(r, "#cbd1b9")
    for cut in layout["WaterCuts"]:
        rect(cut, "#327d94")
    for room in layout["Rooms"]:
        if room["kind"] == "marine":
            continue
        if "rect" in room:
            rect(room["rect"], colors.get(room["kind"], "#dce4db"))
        else:
            points = " ".join(f"{p[0]},{p[1]}" for p in room["polygon"])
            out.append(f'<polygon points="{points}" fill="{colors[room["kind"]]}"/>')
    for courtyard in layout["Courtyards"]:
        rect(courtyard["rect"], colors[courtyard["habitat"]])
    rect(layout["Dock"], "#bd965f")
    rect(layout["DockRamp"], "#e6bd7c")
    rect(layout["SwimSteps"], "#c6d9c5", 'opacity=".7"')
    for exit in layout["ShoreExits"]:
        x, y, dx, dy = exit["x"], exit["y"], exit["dx"], exit["dy"]
        out.append(f'<line x1="{x}" y1="{y}" x2="{x+dx*40}" y2="{y+dy*40}" stroke="#d6bd8b" stroke-width="20"/>')
        for i in range(1, 17):
            sx, sy = x + dx * i * 2.5, y + dy * i * 2.5
            out.append(f'<line x1="{sx-dy*10}" y1="{sy+dx*10}" x2="{sx+dy*10}" y2="{sy-dx*10}" stroke="#526c60" stroke-width="1"/>')
        out.append(f'<circle cx="{x}" cy="{y}" r="10" fill="#a0e2be"/><text x="{x+18}" y="{y+8}" fill="#eff4cf" font-size="18">EXIT</text>')
    for ax, ay, bx, by in data["walls"]:
        out.append(f'<line x1="{ax}" y1="{ay}" x2="{bx}" y2="{by}" stroke="#233e42" stroke-width="5" stroke-linecap="square"/>')
    for i, zone in enumerate(layout["Zones"], 1):
        r = zone["rect"]
        x, y = (r[0]+r[2])/2, (r[1]+r[3])/2
        out.append(f'<rect x="{r[0]}" y="{r[1]}" width="{r[2]-r[0]}" height="{r[3]-r[1]}" rx="8" fill="none" stroke="#f4dfa2" stroke-width="3" stroke-dasharray="10 8"/>')
        out.append(f'<circle cx="{x}" cy="{y}" r="21" fill="#f2dfab"/><text x="{x}" y="{y+7}" text-anchor="middle" font-size="22" fill="#153843" font-weight="bold">{i}</text>')
        caption_color = "#f4ebd4" if zone["habitat"] in ("reef", "ocean") else "#153843"
        out.append(f'<text x="{x}" y="{y+48}" text-anchor="middle" font-size="20" fill="{caption_color}" font-weight="bold">{html.escape(zone["name"])}</text>')
    for point, caption in [(layout["Spawn"], "START"), (layout["Hub"], "ARK HUB")]:
        x, y = point
        out.append(f'<circle cx="{x}" cy="{y}" r="12" fill="#ff967d"/><text x="{x}" y="{y-22}" text-anchor="middle" font-size="26" font-weight="bold" fill="#173c45">{caption}</text>')
    gx, gy = layout["SeaGate"]
    out.append(f'<path d="M{gx-35},{gy} h90 m-18,-12 l18,12 l-18,12" fill="none" stroke="#f5dda7" stroke-width="6"/><text x="{gx+30}" y="{gy-24}" fill="#f5dda7" font-size="22">SEA GATE</text>')
    out.append('<text x="1590" y="105" fill="#e9dcbd" font-size="24">N ↑</text><text x="1550" y="670" fill="#add7cf" font-size="21">Open-sea gameplay extension</text>')
    out.append('<text x="60" y="1660" fill="#f7e9c8" font-size="22">Trace is approximate. Small rooms are consolidated; roofs omitted for outdoor play.</text>')
    out.append('<text x="60" y="1700" fill="#add7cf" font-size="20">0.6 studs / source pixel is a gameplay scale, not an architectural measurement.</text></g></svg>')
    target = Path("docs/map-1-layout.svg")
    target.write_text("\n".join(out) + "\n")
    return target

if __name__ == "__main__":
    data = load_map()
    check_layout(data)
    target = render_svg(data)
    Path("build").mkdir(exist_ok=True)
    Path("build/map-1-layout.json").write_text(json.dumps(data, indent=2) + "\n")
    print("Layout review diagram:", target)
