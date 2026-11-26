---
name: anti-slop-game-ui
description: >-
  Anti-Slop UI and distinctive visual design rules synthesized from anthropics/skills (frontend-design)
  and pbakaus/impeccable (craft-floor, animate, critique-rubric). Eliminates generic AI SaaS rounded cards,
  purple/blue translucent gradient boxes, uniform border-radius, and linear hover/fade defaults in favor
  of subject-grounded game HUDs, floating high-contrast typography, chamfered/double-line frames, and
  intentional motion.
license: "MIT / Apache-2.0 (Upstream: anthropics/skills & pbakaus/impeccable)"
---

# Anti-Slop Game UI & Distinctive Frontend Design

> Upstream sources bundled in `references/`:
> - `references/anthropic-frontend-design.md` (`github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md`)
> - `references/impeccable-craft-floor.md` (`github.com/pbakaus/impeccable/blob/main/.agent/skills/impeccable/reference/craft-floor.md`)
> - `references/impeccable-animate.md` (`github.com/pbakaus/impeccable/blob/main/.agent/skills/impeccable/reference/animate.md`)
> - `references/impeccable-critique-rubric.md` (`github.com/pbakaus/impeccable/blob/main/.agent/skills/impeccable/reference/critique-rubric.md`)

---

## Part 1: Eliminate Generic AI Slop Patterns (`anthropics/skills` + `pbakaus/impeccable`)

Approach every UI and HUD as the art director at a studio known for giving every world an unmistakable visual identity. Reject proposals that read as templated defaults:

### Absolute Refusals & AI-Tell Calibration
1. **No SaaS-Card Kit in Games**: Never chop content or HUD readouts into identical rounded rectangles (`border-radius: 12px..24px` / `border_radius=14..24`), uniform translucent dark-purple/indigo boxes (`rgba(36, 32, 62, 0.85)`), or decorative purple-blue gradient washes. Cards are lazy containers; nested cards are always wrong.
2. **No Template Chrome**:
   - Ban tracked-out ALL-CAPS eyebrow/kicker labels above headings. Let the heading carry its own weight.
   - Ban generic numbered markers (`01 / 02 / 03`) unless the content is strictly a sequential timeline.
   - Ban zero-offset colored neon halos pretending to be depth; real depth uses directional offset shadows, occlusion vignettes, and warm/cool light separation.
   - Ban Unicode/emoji stand-ins where custom geometric/vector glyphs or authored silhouettes belong.
3. **Ground Every Frame in the Subject's World**:
   - Derive palette, framing, and ornament from the game's physical materials (e.g., twilight forest bark, botanical parchment, brass/gold filigree, carved slate, bioluminescent spores) rather than admin-dashboard pills.
   - **Floating Game-Grade HUD**: Prefer **borderless floating typography** anchored to screen safe-areas, backed only by crisp multi-pass dark stroke/drop-shadow or a soft single-edge directional vignette/gradient mask.
   - **Intentional Framing When Containers Are Needed**: When interactive buttons, character plates, or narrative banners genuinely require a backing plate, use **crisp 90° architectural corners, 45° chamfered/beveled polygons, double-hairline inset frames, corner bracket ticks, or weathered/textured organic edges** — never default `border-radius` pills.

---

## Part 2: Craft Floor & Visual Hierarchy (`pbakaus/impeccable/reference/craft-floor.md`)

- **Contrast**: Body and gameplay readout text >= 4.5:1; large display text >= 3:1. Never use dead neutral gray on colored surfaces — tint secondary text from the world's warm or cool light hue.
- **Depth**: Shadows must carry directional offset and soft falloff, never flat unshifted halos.
- **Spacing & Cognitive Load**: Keep <= 4 distinct data points per HUD cluster (Cowan's working memory rule). Tight internal grouping, generous separation between clusters.
- **Typography**: Clear scale and weight contrast. Spend visual boldness in one focal place; keep peripheral hints quiet and disciplined.

---

## Part 3: Purposeful Motion & Hover Discipline (`pbakaus/impeccable/reference/animate.md`)

- **Timing & Asymmetric Easing**:
  - `100–150 ms`: immediate control/button acknowledgment.
  - `150–300 ms`: state change, HUD counter pop, or banner reveal.
  - `300–500 ms`: scene or overlay transition.
  - **Exit faster than entrance.** Use confident exponential/cubic ease-out (`1 - (1 - t)^3` or overshoot `EaseOutBack`) from an already-legible state; never use sluggish linear ramps.
- **Hover Stability**: Hover motion must never shift the hit-target out from under the pointer (avoid moving the hitbox rect itself on hover; animate internal layers, brackets, scale, or luminance while keeping hit geometry stable).
- **One Authored Focal Moment**: Avoid scattering identical sine-bob or fade-up animations across every element. Anchor motion to player input and world events.
