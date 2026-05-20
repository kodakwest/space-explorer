# Space Explorer — Godot 4.6.2

3D star and constellation study tool with navigable star systems. Built in Godot 4.6.2, Blueprint-only (no C++).

## Visual Conventions

### Drift Aesthetic (Zen Drift / Stellar Drift inspired)

**Color Palette:**
- Abyss (bg): #08070a — deep space void
- Nebula inner: #241638 — purple gas
- Nebula mid: #152447 — blue gas  
- Nebula outer: #171e2e — cyan gas
- Nebula accent: #33172b — magenta gas
- Star warm: #ebc884 — gold star
- Star cool: #82aad9 — blue-white star
- Star base: #d9dce6 — white star
- Core glow: #ffdd80 — warm center
- UI accent: #5ce1e6 — teal cyan (HUD)

**Star system:** Galaxy spiral arms, warm core, cool arms, twinkle animation, MultiMesh for performance.

**Constellations:** 8 major constellations with proximity-based discovery. Thin glowing lines, fade-in teal labels.

**Ship:** Teal-blue metal, warm engine glow, minimal HUD.

**Atmosphere:** Calm, drifting, no combat, pure exploration. Deep nebula background, floating dust particles.

## Design Conventions

- Dark theme throughout (#08070a backgrounds, #d9dce6 text)
- Teal accent (#5ce1e6) for interactive elements and HUD
- Monospace font (Courier New / system monospace) for HUD text
- Minimal UI — low opacity, fades on idle
- No chrome, no buttons during exploration flight
- Glow effects (WorldEnvironment glow enabled)
- Billboard labels for constellation names
- Smooth transitions (ease-in-out, not instant)

## Educational UX Direction

The app should feel like a **digital planetarium + space flight sim**:
1. Discovery-based — fly to a constellation, it reveals itself
2. Star info on approach — name, magnitude, distance, type
3. Guided tours — "Follow the stars to find Orion"
4. Bookmarks — mark discoveries, track what you've found
5. Quiz mode — "Which star is the brightest in the night sky?"

## Output Requirements

- All `.gd` scripts use Godot 4.6.2 GDScript syntax
- Scene files (`.tscn`) are text-format, version-control friendly
- HTML design artifacts (mood boards, flow docs) go in `/design/` directory
- Responsive HTML if building web artifacts

## Tech Stack

- Godot 4.6.2
- GDScript only (no C++)
- Godot AI MCP plugin for AI-assisted editing
- GitHub for version control

## Testing

- F5 to run from editor
- Check all scene references are valid
- Verify constellation discovery works by flying within 50 units
- No runtime errors in Output panel
