---
name: shader-visual-polish
description: >-
  Procedural surface craft, multi-scale noise (value/gradient/fBm/Voronoi/domain-warp), organic roughness
  and material breakup, water optics, linear lighting, warm/cool light contrast, and dithering rules
  synthesized from gokayfem/shader-skills (shader-art-coding). Eliminates flat plastic solid fills and
  checkerboard symmetry in 2D/3D game worlds.
license: "MIT (Upstream: gokayfem/shader-skills)"
---

# Shader & Procedural Visual Polish (Anti-Plastic Surface Craft)

> Upstream sources bundled in `references/`:
> - `references/shader-art-coding-SKILL.md` (`github.com/gokayfem/shader-skills/blob/main/skills/shader-art-coding/SKILL.md`)
> - `references/noise-use-cases.md` (`github.com/gokayfem/shader-skills/blob/main/skills/shader-art-coding/references/noise-use-cases.md`)
> - `references/material-sampling.md` (`github.com/gokayfem/shader-skills/blob/main/skills/shader-art-coding/references/material-sampling.md`)
> - `references/water-quality.md` (`github.com/gokayfem/shader-skills/blob/main/skills/shader-art-coding/references/water-quality.md`)

---

## 1. Visual Engineering Against "Plastic Look"

Flat RGB fills (`fill((118, 178, 122))`), binary `(row + col) % 2` checkerboards, and un-tinted radial alpha circles create an unmistakable "plastic / MS-Paint prototype" look. Fix them in ordered stages:

1. **Break Grid & Checkerboard Symmetry (`noise-use-cases.md` & `material-sampling.md`)**:
   - Replace `(row + col) % 2` alternating flat tiles with **continuous world-space multi-octave value/gradient noise (fBm)** combined with micro-grain hash variation (`hash12` / integer PCG hash, never `sin()*43758.5453` artifacts).
   - Separate frequencies by job:
     - **Low frequency (`fBm` 2–3 octaves)**: broad moss/soil moisture patches, clearing warmth vs. deep-woods shadow.
     - **Medium frequency (cellular / clustered scatter)**: clover patches, pebbles, fallen petals, bark crevices, shoreline foam/ripples.
     - **High frequency (micro-noise / TPDF dither)**: subtle `±3..7` luminance/hue grain baked into cached ground, foliage, wood, and UI slate surfaces so no 20×20px patch is a dead solid color.
2. **Organic Silhouettes Over Primitive Boxes**:
   - Bushes, tree canopies, shoreline banks, and wooden planks should never look like rounded rectangles (`border_radius=16`) stamped on a grid. Use overlapping asymmetric botanical clusters, root/undergrowth ground shadows, bark grain, and shoreline mud/pebble transitions where water (`~`) meets meadow (`.`).
3. **Water Depth, Caustics & Shore Contact (`water-quality.md`)**:
   - Give water depth gradient (darker teal-indigo in deeper center, brighter turquoise-emerald near banks), animated multi-band caustic/ripple curves, specular glints, and soft bank foam/edge stones so water sits *inside* the terrain rather than floating on top as a flat blue square.
4. **Warm / Cool Lighting Contrast & Atmospheric Grading**:
   - **Cool Ambient Shadow**: Deep twilight forest canopy and fog carry cool slate-indigo/ pine-cyan undertones (`(16, 24, 42)`), not muddy gray-purple.
   - **Warm Golden / Bioluminescent Key Lights**:
     - Player lantern aura: warm amber-gold core (`(255, 215, 145)`) transitioning smoothly into soft rose-gold falloff.
     - Lit mushrooms: bioluminescent cyan-mint & emerald halo (`(110, 250, 210)`) casting additive colored bounce light onto nearby grass and characters!
     - Reunion tree-hollow goal: warm hearth-peach / golden-rose glow (`(255, 190, 140)`), creating immediate **warm vs. cool chromatic storytelling** across the twilight fog.
   - **Banding Prevention**: Add subtle procedural grain/dithering to large gradients and fog/light masks so radial falloffs look velvety rather than banded rings.
5. **Performance Discipline**:
   - Bake expensive world-space fBm / micro-noise terrain & static canopy layers once at level init into converted `pygame.Surface` caches; animate lightweight water caustics, spore motes, additive light halos, and foliage sway in real time at locked 60 FPS.
