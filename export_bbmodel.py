"""Generate native Blockbench (.bbmodel) editable projects for boy_chibi and girl_chibi."""
import base64
import io
import json
import uuid
from pathlib import Path
from PIL import Image


PALETTE = [
    ("skin", (255, 217, 189, 255)),       # 0
    ("hair", (41, 36, 36, 255)),          # 1
    ("eye", (31, 26, 31, 255)),           # 2
    ("blush", (255, 148, 158, 255)),      # 3
    ("white", (245, 245, 250, 255)),      # 4
    ("sole", (230, 227, 219, 255)),       # 5
    ("boy_shirt", (61, 64, 71, 255)),     # 6
    ("boy_rib", (46, 48, 56, 255)),       # 7
    ("boy_pant", (112, 115, 79, 255)),    # 8
    ("boy_cuff", (92, 94, 64, 255)),      # 9
    ("boy_shoe", (71, 112, 82, 255)),     # 10
    ("leaf", (82, 204, 102, 255)),        # 11
    ("clear_g", (215, 232, 245, 190)),    # 12
    ("girl_blue", (168, 214, 245, 255)),  # 13
    ("girl_cream", (242, 237, 219, 255)), # 14
    ("girl_short", (115, 122, 138, 255)), # 15
    ("girl_shoe", (107, 158, 214, 255)),  # 16
    ("gold", (245, 200, 75, 255)),        # 17
    ("dark_btn", (70, 75, 90, 255)),      # 18
]

COLOR_IDX = {name: idx for idx, (name, _) in enumerate(PALETTE)}


def make_palette_b64() -> str:
    # 16x16 palette grid (each color gets a 2x2 cell so UV sampling has zero bleed)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    for idx, (_, rgba) in enumerate(PALETTE):
        cx = (idx % 8) * 2
        cy = (idx // 8) * 2
        for dx in (0, 1):
            for dy in (0, 1):
                px[cx + dx, cy + dy] = rgba
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def uv_for(color_name: str) -> list[float]:
    idx = COLOR_IDX[color_name]
    cx = (idx % 8) * 2
    cy = (idx // 8) * 2
    return [cx + 0.5, cy + 0.5, cx + 1.5, cy + 1.5]


def make_cube(name: str, center: tuple[float, float, float], size: tuple[float, float, float], color_name: str, origin: tuple[float, float, float] | None = None) -> dict:
    # Convert Godot meters -> Blockbench pixels (1m = 16px)
    cx, cy, cz = [v * 16.0 for v in center]
    sx, sy, sz = [v * 16.0 for v in size]
    uv = uv_for(color_name)
    faces = {
        d: {"uv": uv, "texture": 0}
        for d in ("north", "east", "south", "west", "up", "down")
    }
    return {
        "name": name,
        "box_uv": False,
        "rescale": False,
        "locked": False,
        "from": [round(cx - sx / 2, 3), round(cy - sy / 2, 3), round(cz - sz / 2, 3)],
        "to": [round(cx + sx / 2, 3), round(cy + sy / 2, 3), round(cz + sz / 2, 3)],
        "autouv": 0,
        "color": 0,
        "origin": [round(v * 16.0, 3) for v in (origin if origin else center)],
        "faces": faces,
        "type": "cube",
        "uuid": str(uuid.uuid4()),
    }


def make_group(name: str, origin: tuple[float, float, float], children: list) -> dict:
    return {
        "name": name,
        "origin": [round(v * 16.0, 3) for v in origin],
        "color": 0,
        "uuid": str(uuid.uuid4()),
        "export": True,
        "mirror_uv": False,
        "isOpen": True,
        "locked": False,
        "visibility": True,
        "autouv": 0,
        "children": children,
    }


def build_bbmodel(role: str, out_path: str) -> None:
    elements = []

    def add_cube(name, center, size, color, origin=None):
        c = make_cube(name, center, size, color, origin)
        elements.append(c)
        return c["uuid"]

    # --- LEGS ---
    leg_groups = []
    shoe_col = "boy_shoe" if role == "boy" else "girl_shoe"
    for side, sx in (("leg_l", -0.17), ("leg_r", 0.17)):
        kids = []
        if role == "boy":
            kids.append(add_cube("pants", (sx, 0.34, 0), (0.24, 0.36, 0.24), "boy_pant", (sx, 0.52, 0)))
            kids.append(add_cube("cuff", (sx, 0.17, 0), (0.25, 0.07, 0.25), "boy_cuff", (sx, 0.52, 0)))
        else:
            kids.append(add_cube("shorts_leg", (sx, 0.46, 0), (0.28, 0.14, 0.28), "girl_short", (sx, 0.52, 0)))
            kids.append(add_cube("leg_skin", (sx, 0.31, 0), (0.18, 0.20, 0.18), "skin", (sx, 0.52, 0)))
            kids.append(add_cube("sock", (sx, 0.18, 0), (0.19, 0.11, 0.19), "white", (sx, 0.52, 0)))
        kids.append(add_cube("sole", (sx, 0.03, 0.05), (0.22, 0.06, 0.33), "sole", (sx, 0.52, 0)))
        kids.append(add_cube("shoe_upper", (sx, 0.09, 0.03), (0.21, 0.11, 0.28), shoe_col, (sx, 0.52, 0)))
        kids.append(add_cube("toe_cap", (sx, 0.08, 0.16), (0.20, 0.10, 0.14), "white", (sx, 0.52, 0)))
        leg_groups.append(make_group(side, (sx, 0.52, 0), kids))

    # --- TORSO ---
    torso_kids = [add_cube("neck", (0, 1.20, 0), (0.26, 0.14, 0.26), "skin")]
    if role == "boy":
        torso_kids += [
            add_cube("sweatshirt", (0, 0.87, 0), (0.66, 0.58, 0.48), "boy_shirt"),
            add_cube("waist_rib", (0, 0.58, 0), (0.64, 0.10, 0.46), "boy_rib"),
            add_cube("collar_rib", (0, 1.13, 0), (0.40, 0.08, 0.38), "boy_rib"),
            add_cube("pocket", (0, 0.72, 0.24), (0.34, 0.16, 0.06), "boy_rib"),
            add_cube("leaf_pin_1", (0.16, 0.96, 0.25), (0.08, 0.11, 0.04), "leaf"),
            add_cube("leaf_pin_2", (0.21, 0.93, 0.24), (0.07, 0.09, 0.04), "leaf"),
        ]
    else:
        torso_kids += [
            add_cube("shorts_waist", (0, 0.55, 0), (0.62, 0.16, 0.48), "girl_short"),
            add_cube("hoodie_blue", (0, 0.90, 0), (0.66, 0.54, 0.48), "girl_blue"),
            add_cube("hoodie_cream", (0, 0.68, 0), (0.68, 0.16, 0.50), "girl_cream"),
            add_cube("hood_back", (0, 1.07, -0.22), (0.46, 0.26, 0.26), "girl_blue"),
            add_cube("shirt_inner", (0, 0.90, 0.23), (0.20, 0.46, 0.08), "white"),
            add_cube("pocket_l", (-0.20, 0.70, 0.24), (0.13, 0.12, 0.05), "girl_cream"),
            add_cube("pocket_r", (0.20, 0.70, 0.24), (0.13, 0.12, 0.05), "girl_cream"),
            add_cube("star_pendant", (0, 0.95, 0.29), (0.11, 0.11, 0.05), "gold"),
        ]
        for idx, by in enumerate((0.98, 0.86, 0.74)):
            torso_kids.append(add_cube(f"btn_{idx}", (0, by, 0.275), (0.035, 0.035, 0.03), "dark_btn"))
    torso_group = make_group("torso", (0, 0.85, 0), torso_kids)

    # --- ARMS ---
    arm_groups = []
    sleeve = "boy_shirt" if role == "boy" else "girl_blue"
    cuff = "boy_rib" if role == "boy" else "girl_cream"
    for side, sx, td in (("arm_l", -0.37, 1.0), ("arm_r", 0.37, -1.0)):
        ak = [
            add_cube("shoulder", (sx, 1.03, 0), (0.20, 0.20, 0.20), sleeve, (sx, 1.05, 0)),
            add_cube("sleeve", (sx, 0.88, 0), (0.19, 0.28, 0.19), sleeve, (sx, 1.05, 0)),
            add_cube("cuff", (sx, 0.74, 0), (0.20, 0.06, 0.20), cuff, (sx, 1.05, 0)),
            add_cube("hand", (sx, 0.66, 0), (0.16, 0.17, 0.16), "skin", (sx, 1.05, 0)),
            add_cube("thumb", (sx + td * 0.07, 0.68, 0.06), (0.07, 0.09, 0.07), "skin", (sx, 1.05, 0)),
        ]
        arm_groups.append(make_group(side, (sx, 1.05, 0), ak))

    # --- HEAD ---
    hy = 1.62
    hk = [
        add_cube("head_base", (0, hy, 0), (0.88, 0.82, 0.84), "skin", (0, hy, 0)),
        add_cube("ear_l", (-0.46, hy - 0.04, 0), (0.14, 0.20, 0.14), "skin", (0, hy, 0)),
        add_cube("ear_r", (0.46, hy - 0.04, 0), (0.14, 0.20, 0.14), "skin", (0, hy, 0)),
        add_cube("eye_l", (-0.18, hy + 0.02, 0.42), (0.10, 0.13, 0.04), "eye", (0, hy, 0)),
        add_cube("eye_r", (0.18, hy + 0.02, 0.42), (0.10, 0.13, 0.04), "eye", (0, hy, 0)),
        add_cube("blush_l", (-0.27, hy - 0.10, 0.41), (0.13, 0.07, 0.03), "blush", (0, hy, 0)),
        add_cube("blush_r", (0.27, hy - 0.10, 0.41), (0.13, 0.07, 0.03), "blush", (0, hy, 0)),
        add_cube("hair_cap", (0, hy + 0.14, -0.05), (0.94, 0.82, 0.90), "hair", (0, hy, 0)),
    ]
    gcol = "clear_g" if role == "boy" else "gold"
    if role == "boy":
        for i, bx in enumerate((-0.24, -0.08, 0.08, 0.24)):
            hk.append(add_cube(f"bang_{i}", (bx, hy + 0.32, 0.32), (0.22, 0.22, 0.22), "hair", (0, hy, 0)))
        hk.append(add_cube("brow_l", (-0.18, hy + 0.14, 0.43), (0.16, 0.04, 0.03), "hair", (0, hy, 0)))
        hk.append(add_cube("brow_r", (0.18, hy + 0.14, 0.43), (0.16, 0.04, 0.03), "hair", (0, hy, 0)))
    else:
        hk.append(add_cube("bang_l", (-0.26, hy + 0.24, 0.28), (0.30, 0.34, 0.24), "hair", (0, hy, 0)))
        hk.append(add_cube("bang_r", (0.26, hy + 0.24, 0.28), (0.30, 0.34, 0.24), "hair", (0, hy, 0)))
        hk.append(make_group("twin_l", (-0.44, hy - 0.10, -0.16), [
            add_cube("tail_l", (-0.52, hy - 0.32, -0.21), (0.24, 0.46, 0.24), "hair", (-0.44, hy - 0.10, -0.16))
        ]))
        hk.append(make_group("twin_r", (0.44, hy - 0.10, -0.16), [
            add_cube("tail_r", (0.52, hy - 0.32, -0.21), (0.24, 0.46, 0.24), "hair", (0.44, hy - 0.10, -0.16))
        ]))

    # Glasses
    gk = []
    for side, sx in (("l", -0.19), ("r", 0.19)):
        gk.append(add_cube(f"g_top_{side}", (sx, hy + 0.09, 0.46), (0.24, 0.03, 0.03), gcol, (0, hy, 0)))
        gk.append(add_cube(f"g_bot_{side}", (sx, hy - 0.07, 0.46), (0.24, 0.03, 0.03), gcol, (0, hy, 0)))
        gk.append(add_cube(f"g_in_{side}", (sx - 0.11, hy + 0.01, 0.46), (0.03, 0.18, 0.03), gcol, (0, hy, 0)))
        gk.append(add_cube(f"g_out_{side}", (sx + 0.11, hy + 0.01, 0.46), (0.03, 0.18, 0.03), gcol, (0, hy, 0)))
    gk.append(add_cube("g_bridge", (0, hy + 0.04, 0.46), (0.14, 0.03, 0.03), gcol, (0, hy, 0)))
    hk.append(make_group("glasses", (0, hy, 0), gk))

    head_group = make_group("head", (0, hy, 0), hk)

    doc = {
        "meta": {
            "format_version": "4.10",
            "model_format": "free",
            "box_uv": False,
        },
        "name": f"{role}_chibi",
        "model_identifier": f"{role}_chibi",
        "visible_box": [1, 1, 0],
        "resolution": {"width": 16, "height": 16},
        "elements": elements,
        "outliner": [head_group, torso_group, *arm_groups, *leg_groups],
        "textures": [
            {
                "path": "palette.png",
                "name": "palette.png",
                "folder": "",
                "namespace": "",
                "id": "0",
                "particle": False,
                "render_mode": "default",
                "render_sides": "auto",
                "frame_time": 1,
                "frame_order_type": "loop",
                "frame_order": "",
                "frame_interpolate": False,
                "visible": True,
                "mode": "bitmap",
                "saved": True,
                "uuid": str(uuid.uuid4()),
                "source": make_palette_b64(),
            }
        ],
    }

    Path(out_path).write_text(json.dumps(doc, indent=2), encoding="utf-8")
    print(f"Saved {out_path} ({len(elements)} cubes)")


if __name__ == "__main__":
    assets = Path(r"e:\Projects\findyou_godot\assets")
    build_bbmodel("boy", str(assets / "boy_chibi.bbmodel"))
    build_bbmodel("girl", str(assets / "girl_chibi.bbmodel"))
