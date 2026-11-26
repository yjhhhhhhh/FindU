---
name: gamedev-craft
description: >-
  Game engineering, 2D movement physics, game-feel (juice), HUD architecture, and Pygame/Godot craft rules
  synthesized from gamedev-skills/awesome-gamedev-agent-skills (pygame-core, game-feel, game-ui-ux,
  godot-2d-movement, godot-shaders) and PatrickJS/awesome-cursorrules. Governs delta-time loops,
  sub-pixel Vector2 physics, asymmetric acceleration/deceleration, hitstop, trauma screen shake,
  input buffering, pitch-randomized audio, and headless verification.
license: "MIT (Upstream: gamedev-skills/awesome-gamedev-agent-skills & PatrickJS/awesome-cursorrules)"
---

# Game Development Craft, Feel (Juice) & 2D Engine Architecture

> Upstream sources bundled in `references/`:
> - `references/pygame-core.md` & `references/pygame-sprites-and-collision.md` (`gamedev-skills/awesome-gamedev-agent-skills`)
> - `references/game-feel.md` & `references/feedback-recipes.md` (`gamedev-skills/awesome-gamedev-agent-skills`)
> - `references/game-ui-ux.md` & `references/layout-and-flow.md` (`gamedev-skills/awesome-gamedev-agent-skills`)
> - `references/godot-2d-movement.md` & `references/godot-shaders.md` (`gamedev-skills/awesome-gamedev-agent-skills`)
> - `references/patrickjs-graphical-apps.mdc` (`PatrickJS/awesome-cursorrules`)

---

## 1. Core Loop & Sub-Pixel Movement (`pygame-core` & `godot-2d-movement`)

1. **Deterministic Clamped Delta-Time**:
   - Drain events every frame (`pygame.event.get()`), clamp `dt = min(clock.tick(FPS) / 1000.0, 0.05)` so window drags never tunnel through walls.
   - Keep simulation Positions in floating-point `pygame.Vector2` (legacy `pygame` `Rect` truncates to `int` and causes jitter; detect `getattr(pygame, "IS_CE", False)` before using `FRect`).
   - Convert loaded surfaces once (`convert()` / `convert_alpha()`) after `display.set_mode()`.
   - Cache static rendered font surfaces and procedural tile layers instead of re-allocating surfaces every frame!
2. **Asymmetric Movement & Jump/Hop Curves (Anti-Linear Motion)**:
   - Never move characters with `pos += dir * constant_speed * dt` (instant infinite acceleration/stop feels robotic and weightless).
   - **Fast Start, Smooth Settle / Crisp Stop**: Use asymmetric acceleration vs. friction/deceleration curves (e.g., high snappy acceleration `accel` with exponential ease-out velocity approach, and distinct turn-around boost when reversing direction).
   - **Asymmetric Vertical Arc (Jump / Hop / Stride)**: Rising phase uses lighter gravity (`gravity_up`), apex has brief hang-time, and falling phase uses heavier gravity (`gravity_down = 1.6x..2.2x gravity_up`) for crisp, weighty landings with squash-and-stretch (`(1.22, 0.80)` on land -> spring back via `EaseOutBack`).
   - **Input Buffering**: Buffer action presses (e.g. `Space` butterfly/hop/interact, menu confirm, directional nudges) in a `0.12s–0.15s` real-time window so inputs pressed during a hitstop or cooldown fire seamlessly the instant the lock clears.

---

## 2. Game Feel & Multi-Channel Juice (`game-feel` & `feedback-recipes`)

Feedback sells every interaction by firing 2–4 brief, proportional responses simultaneously on discrete event hooks without corrupting collision coordinates:

| Tier | Trauma | Hitstop (Real-Time) | Particles | Audio & Visual Extra | Example Events |
|------|:------:|:-------------------:|:---------:|----------------------|----------------|
| **Small** | `0.06–0.14` | `0.00s` | `2–5` | Soft footstep dust, subtle pitch-varied tick | Footstep, button hover, wall brush |
| **Medium** | `0.25–0.42` | `0.035–0.055s` | `12–20` | Scale pop (`EaseOutBack`), sprite rim flash, chord chime | Lighting mushroom, pressing UI button, hopping |
| **Large** | `0.55–0.80` | `0.075–0.110s` | `28–45` | Shockwave ring, camera nudge, harmonic arpeggio | Note-pad resonance, vine gate unlock, keepsake, reunion |

### Critical Juice Rules
1. **Trauma-Based Screen Shake (`shake = trauma^2`)**:
   - Track `trauma` in `[0, 1]`, decaying linearly in **unscaled real time** (`real_dt`).
   - Compute camera visual offset using **summed incommensurate sines** (`0.6*sin(t*11) + 0.4*sin(t*23)`), NEVER `random.uniform()` per frame (which buzzes like broken static).
   - Apply shake strictly to the **render camera offset**, never mutating entity physics positions.
2. **Safe Real-Time Hitstop**:
   - Scale simulation `dt` (`sim_dt = real_dt * time_scale`, e.g., `0.05` during hitstop) while advancing `hitstop_timer`, `trauma` decay, input buffer timers, and UI tweens using unscaled `real_dt`.
   - Track `_hitstop_id` / max remaining timer so overlapping events never get stuck or prematurely unfreeze.
3. **Pitch Micro-Randomization**:
   - Never play identical raw samples repeatedly. Randomize playback pitch by `±6%..12%` (`pitch_factor = random.uniform(0.92, 1.09)`) on footsteps, pickups, mushroom blooms, and UI clicks to eliminate mechanical repetition fatigue.

---

## 3. Event-Driven HUD & Input Navigation (`game-ui-ux`)

- **Anchor to Safe Areas**: Inset critical HUD counters from screen edges (`20–28px` margin); let atmospheric vignette/art bleed to `0,0`.
- **Keyboard + Mouse Coexistence**: Every screen (`SELECT`, `PLAY`, `CLEAR`) must maintain a clear focused option for keyboard navigation (`Left/Right/A/D/1/2/Enter/Esc`) alongside mouse hover without clearing keyboard usability when the mouse rests.
- **Headless Verification**: Support `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy` smoke runs and screenshot dumps so every state (`SELECT`, `PLAY`, `CLEAR`) can be visually verified!
