# Movement design references

Read the public PostHog source on 2026-09-07 and inspected the live Hedgehog Mode playground. This work uses no PostHog customer analytics or project data.

Primary references:

- [Actor physics and dragging](https://github.com/PostHog/hedgehog-mode/blob/main/hedgehog-mode/src/actors/Actor.ts): gravity-driven Matter body, restitution 0.5, air friction 0.01, upright orientation, edge wrapping after the body leaves the viewport. Drag starts after a 10-pixel threshold and attaches a constraint with stiffness 0.2, damping 1, length 2. Releasing removes the constraint without zeroing velocity.
- [Keyboard controls](https://github.com/PostHog/hedgehog-mode/blob/main/hedgehog-mode/src/actors/hedgehog/controls.ts): left/right horizontal motion; Up/W/Space jump; Shift doubles walking speed. Down disables platform collisions and can cancel upward velocity. The user's explicit requirement here overrides that Down behavior: always face the viewer.
- [Default skin](https://github.com/PostHog/hedgehog-mode/blob/main/hedgehog-mode/src/actors/hedgehog/skins.ts): two consecutive jumps with a jump velocity of -15 in Matter's units.
- [Hedgehog animation](https://github.com/PostHog/hedgehog-mode/blob/main/hedgehog-mode/src/actors/Hedgehog.ts): airborne animation when unsupported, walking on horizontal motion while grounded, otherwise idle. The game has one-way platforms derived from page elements.

Native adaptation:

- Feet have a position in macOS screen coordinates. The transparent panel follows that position so jumps are real desktop travel, rather than a small sprite offset inside a stationary window.
- Each connected display contributes its usable bottom edge as a floor. The displays share one world, and wrapping occurs only beyond the outer desktop edges. No screenshots, Accessibility tree scanning, or inferred application-window platforms are used.
- Crossing an outer edge wraps while preserving height and velocity; internal monitor seams never wrap. Ground travel follows floor offsets between monitors. The native panel permits offscreen placement so AppKit does not push Rick back at the edge. Dragging bypasses wrapping until release.
- Gravity is 1800 points/s². A jump is tuned to rise 42% of usable screen height, bounded to 180–380 points, plus one extra jump in midair. The numerical constants are native tuning, not a unit-for-unit port of Matter.js. Jumps land without repeated bounces; throws use restitution 0.48 and dissipate energy.
- Drag uses a critically damped spring with an exact time-step solution and a 120 ms pointer-velocity window. Release blends that velocity with the body's spring velocity and caps extreme throws at 2800 points/s. A stationary hold discards stale flick samples.
- Walking uses grounded frames only. Front-facing input overrides horizontal and aerial motion. Starting a new horizontal input releases the facing lock.
- Focus changes clear keys but preserve airborne momentum. Hovering pauses floor roaming, not gravity. Pausing in midair settles on the floor. Portals and summoning arrive on the floor.

No PostHog implementation code is copied into the app. Downloaded reference-code snapshots were removed during the source cleanup; the primary source links above retain the design context. Current recorded dialogue and its matching captions are documented in `VOICE_PACKS.md`.
