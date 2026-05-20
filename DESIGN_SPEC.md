# Space Explorer — Design & Phase Plan

## Aesthetic Direction (from Zen Drift / Stellar Drift)

### Color Palette (HSB → RGBA equivalent)

| Element | HSB | RGBA Hex | Description |
|---------|-----|----------|-------------|
| Abyss (bg) | 260°, 25%, 4% | #08070a | Deep space void |
| Nebula inner | 270°, 60%, 22% | #241638 | Purple gas |
| Nebula mid | 230°, 70%, 28% | #152447 | Blue gas |
| Nebula outer | 200°, 50%, 18% | #171e2e | Cyan gas |
| Nebula accent | 320°, 55%, 20% | #33172b | Magenta gas |
| Star warm | 30°, 60%, 92% | #ebc884 | Gold star |
| Star cool | 220°, 40%, 85% | #82aad9 | Blue-white star |
| Star base | 220°, 10%, 95% | #d9dce6 | White star |
| Core glow | 40°, 50%, 100% | #ffdd80 | Warm center |
| UI accent | — | #5ce1e6 | Teal cyan (HUD) |

### Visual System

1. **Star Distribution** — Galaxy spiral arms (3 arms), dense warm core, scattered cool arms
2. **Star Colors** — Core stars warm (gold/orange), arm stars cool (blue/white), size varies by magnitude
3. **Twinkle** — Subtle alpha oscillation per star, randomized phase
4. **Nebula** — Multi-layer Perlin noise as skybox/background, purple→blue→magenta gradients
5. **Dust Particles** — Hundreds of tiny faint particles floating across the scene
6. **Constellation Lines** — Thin lines between key stars, revealed on proximity, color matches star type
7. **Ship Glow** — Warm teal engine glow, subtle headlight
8. **HUD** — Minimal, clean, monospace font, low-opacity text, teal accent color
9. **Atmosphere** — Calm, drifting, no combat, pure exploration

### Zen Drift UX Patterns

- **Mouse control**: Smooth ease-to-cursor with friction (0.94 drag, 0.012 ease)
- **Discovery**: Constellations reveal when ship/camera is within proximity radius
- **Audio**: Tonal chime on constellation discovery (optional)
- **Labeling**: Fade-in names with subtle glow
- **Minimal UI**: No chrome, no buttons during exploration
- **Pause**: Space to freeze and inspect

## Phase Plan

### Phase 2 — Visual Overhaul (THIS SPRINT)
Goal: Transform the current prototype into the drift aesthetic

- [ ] Galaxy-distributed star field (spiral arms, warm/cool colors, magnitude-based sizing)
- [ ] Star twinkle shader/animation
- [ ] Nebula skybox (procedural or texture-based)
- [ ] Dust particle system
- [ ] Constellation data system (8-12 major constellations with real star positions)
- [ ] Constellation line rendering (thin connections, glow on proximity)
- [ ] Constellation discovery mechanic (fly near → reveal name + lines)
- [ ] Star info popup (click/fly near star → name, distance, magnitude)
- [ ] Warm ship engine glow
- [ ] HUD redesign (minimal, teal, monospace)
- [ ] Smooth camera feel (easing, drift)

### Phase 3 — Real Star Data
Goal: Replace procedural stars with real astronomical data

- [ ] Import HYG Database or similar star catalog (RA/Dec, magnitude, B-V color, distance)
- [ ] Render 3D star positions in space
- [ ] Bayer/Flamsteed designations for bright stars
- [ ] Real constellation boundaries and lines
- [ ] Click-to-select star, see detailed info card
- [ ] Search/browse stars by name or constellation

### Phase 4 — Educational Content
Goal: Make it a learning tool

- [ ] Guided tours ("Follow Orion's belt", "Find the North Star")
- [ ] Constellation mythology cards
- [ ] Quiz mode ("Which constellation contains Betelgeuse?")
- [ ] Observation log / bookmark stars
- [ ] Scale visualization (star size comparison, distance indicators)
- [ ] Recording/tracking what you've discovered

### Phase 5 — Exploration & Travel
Goal: Deep exploration mechanics

- [ ] "Jump drive" between star systems (zoom out → select destination → travel animation)
- [ ] Procedural planets around some stars
- [ ] Planet orbits (time-lapse mode)
- [ ] Planetary info (size, composition, distance from star)
- [ ] Coordinate/Navigation system

## Immediate Next Steps (Codex This Session)

1. **Star System Overhaul** — Replace random star_field.gd with galaxy-distributed stars (spiral arms, warm/cool palette)
2. **Star Twinkle** — Add twinkle animation via shader or script
3. **Color Palette Update** — Apply drift palette to ship materials and environment
4. **Nebula Background** — Procedural nebula as skybox or backdrop
5. **Dust Particles** — Add floating dust particle system
6. **Constellation Data** — Hard-code 8 constellations with point positions and connections
7. **Constellation Rendering** — Draw lines between constellation stars
8. **HUD Polish** — Clean, minimal HUD with teal accents
