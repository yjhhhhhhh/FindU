"""Prepare clean transparent 1x4 sprite sheets (including enclosed white pockets), victory heart, and radial light."""
from collections import deque
from pathlib import Path
from PIL import Image


def remove_bg_and_pockets(img: Image.Image, remove_enclosed_white: bool = True) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    visited = [[False] * w for _ in range(h)]
    q = deque()

    def is_bg(r: int, g: int, b: int) -> bool:
        return r >= 232 and g >= 232 and b >= 232 and max(r, g, b) - min(r, g, b) <= 20

    # 1. Outer border flood-fill
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(*px[x, y][:3]):
                visited[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x] and is_bg(*px[x, y][:3]):
                visited[y][x] = True
                q.append((x, y))

    while q:
        cx, cy = q.popleft()
        px[cx, cy] = (255, 255, 255, 0)
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                if is_bg(*px[nx, ny][:3]):
                    visited[ny][nx] = True
                    q.append((nx, ny))

    # 2. Remove enclosed pure-white background pockets (e.g. between legs / under arms)
    # Only target very bright neutral white (r,g,b >= 244, chroma <= 8) in the lower 65% of the image
    # or medium/large pockets, while keeping small eye highlights / shirt stripes intact.
    if remove_enclosed_white:
        seen = [[False] * w for _ in range(h)]
        for y in range(int(h * 0.38), h):
            for x in range(w):
                if seen[y][x] or px[x, y][3] == 0:
                    continue
                r, g, b, _ = px[x, y]
                if r >= 242 and g >= 242 and b >= 242 and max(r, g, b) - min(r, g, b) <= 10:
                    comp = []
                    cq = deque([(x, y)])
                    seen[y][x] = True
                    while cq:
                        cx, cy = cq.popleft()
                        comp.append((cx, cy))
                        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] > 0:
                                nr, ng, nb, _ = px[nx, ny]
                                if nr >= 238 and ng >= 238 and nb >= 238 and max(nr, ng, nb) - min(nr, ng, nb) <= 14:
                                    seen[ny][nx] = True
                                    cq.append((nx, ny))
                    # Enclosed gap between limbs/arms is typically >= 35 pixels
                    if len(comp) >= 35:
                        for cx, cy in comp:
                            px[cx, cy] = (255, 255, 255, 0)

    # 3. Soften 1px anti-aliased fringe adjacent to transparent pixels
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r >= 200 and g >= 200 and b >= 200 and max(r, g, b) - min(r, g, b) <= 24:
                if any(px[nx, ny][3] == 0 for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                    lum = (r + g + b) / 3.0
                    px[x, y] = (r, g, b, max(0, min(255, int((246 - lum) * 3.8))))
    return img


def process_walk_sheet(src: str, dst: str, frame_w: int = 192, frame_h: int = 256) -> None:
    img = remove_bg_and_pockets(Image.open(src), remove_enclosed_white=True)
    w, h = img.size
    col_w = w // 4
    out = Image.new("RGBA", (frame_w * 4, frame_h), (0, 0, 0, 0))

    crops = []
    max_ch = 1
    for i in range(4):
        cell = img.crop((i * col_w, 0, (i + 1) * col_w if i < 3 else w, h))
        bbox = cell.getbbox()
        if bbox:
            cell = cell.crop(bbox)
        crops.append(cell)
        max_ch = max(max_ch, cell.height)

    target_h = int(frame_h * 0.88)
    scale = target_h / max_ch

    for i, cell in enumerate(crops):
        nw = max(1, int(cell.width * scale))
        nh = max(1, int(cell.height * scale))
        resized = cell.resize((nw, nh), Image.Resampling.LANCZOS)
        dx = i * frame_w + (frame_w - nw) // 2
        dy = (frame_h - 10) - nh
        out.paste(resized, (dx, dy), resized)

    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, "PNG")
    print(f"Saved clean walk sheet {dst}: {out.size}")


def process_victory_heart(src: str, dst: str, size: int = 560) -> None:
    img = remove_bg_and_pockets(Image.open(src), remove_enclosed_white=False)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")
    print(f"Saved victory heart {dst}: {img.size}")


def make_radial_light(dst: str, size: int = 256) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    half = size / 2.0
    for y in range(size):
        for x in range(size):
            d = ((x - half) ** 2 + (y - half) ** 2) ** 0.5 / half
            if d < 1.0:
                a = int(255 * ((1.0 - d) ** 1.7))
                px[x, y] = (255, 255, 255, a)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")


if __name__ == "__main__":
    brain = Path(r"C:\Users\Administrator\.gemini\antigravity\brain\ef129a3e-1101-455e-8de0-9b0222bf462c")
    assets = Path(r"e:\Projects\findyou_godot\assets")
    process_walk_sheet(str(brain / "boy_walk_sprite_sheet_v2_1795605740895.jpg"), str(assets / "boy_walk.png"))
    process_walk_sheet(str(brain / "walk_sprite_sheet_v3_1795605780728.jpg"), str(assets / "girl_walk.png"))
    process_victory_heart(str(brain / "victory_heart_couple_1795605728621.jpg"), str(assets / "victory_heart.png"))
    make_radial_light(str(assets / "light_radial.png"))
