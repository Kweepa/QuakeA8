# Quake on the Atari 8-bit

A line-drawn *Quake* demake for the Atari 8-bit: portal rooms, stick-figure enemies, and a mode-E world. The playable disk is `quakea8.atr`. Boot it in Altirra (800XL, 64K). The menu starts **E1M1**.

## Display

The 3D view is a **mode-E** window under a 9-row text HUD. The world is still projected at 192×128; the plotter keeps every other column, so 96 colour-clock pixels are drawn in the middle of each 32-byte row. Two bitmaps (`$C000` and `$E000`) swap each frame. Lines are unrolled Bresenham bodies in `a8line.asm`.

The HUD is the text window: title, map name, shells / nails / grenades, health, armour, and a powerup icon. Pickup names and trigger messages flash on a status line. Frame time in ms can sit on row 0.

## World

The map is **rooms as axis-aligned hulls**, not a global mesh. Floor plans can be a box or a tetromino (**T / L / S**, including a proper S dogleg). Collision is 8-bit tests against the room’s collider boxes. Closed doors are blocking planes; open doors are walk-throughs that switch the active room. Silver and gold keys unlock matching doors. Only the current room is drawn — doorways do not punch a view into the next one.

Ramps use the AABB for **rise/run** (`height = slope_y + (local * sy) / run` in 8.8) so the eye rides the slope. Elevators, switches, and crates share the same box tests. Step off a ledge and you fall; a hard landing costs health.

Walk-over **backpacks** grant ammo, weapons, health, armour, keys, and the exclusive powerups (quad / pentagram / ring). Killed enemies can drop a pack. Message, hurt, teleport, and elevator **triggers** are undrawn AABBs; a switch can arm a trigger that would otherwise stay inert. End-of-level advances `e1mN` or returns to the menu endings.

Off-screen **items** (AABB meshes) and **enemies** skip rotate/project/draw. Horizontal and vertical tests use a fat 45° cone (`|axis| ≤ z` plus a size pad) so the miss is drawing something a bit off-screen, not dropping something that is still in the 192×128 view. The active room’s bounding lines are not frustum-culled.

There’s an editor for maps (Unity-style orbit in the viewport), item meshes, weapon sprites, and enemy animations retargeted from the original MDLs.

## Entities

Enemies are **13 vertices / 13 lines** on a shared skeleton (Grunt, Knight, Rottweiler, Scrag, Ogre, Shambler, Chthon, Zombie). Poses live in local space as signed offsets from the creature base. All animations are imported from the original data by retargeting the vertex animation to the skeleton. A few KB of poses per type, plus one line layout.

They run a room-scoped state machine (idle / patrol / alert / approach / attack / pain / death). Grunt, Rottweiler, Ogre, and Scrag behaviour is in; the others still share the skeleton and clips. Scrag hovers, spits, and falls on death. E1M1 places Grunts and a rottweiler.

Yaw is rolled(!) into the world rotation to avoid a double rotate. Perspective and rotation use 8-bit **log / antilog LUTs** (`alog(log|x| + log|cos θ|)`).

**Axe** is melee. **Super shotgun** is a hitscan with range falloff, blood on a hit and a wall splat on a miss. **Nailgun** is a tighter hitscan (smaller cone, lower damage, same LOS / splat path). **Grenade launcher** throws a bouncing grenade (player and ogre) with splash damage. The blast is a half-dome of charset pixels: six unique directions, the other three quadrants filled with 90° Y rotates.

The player weapon is stamped into the mode-E bitmap (body, muzzle, enemy muzzle, impact splat). Bob and recoil move that stamp.

SFX are PC-speaker envelopes on POKEY channels (player / enemy / world).

## Build

6502 (ACME) plus Python table generators. Copy `setup-env.example.bat` to `setup-env.bat` and point `ACME` at your install.

```bat
build-a8.bat       :: generate listings, assemble PRGs, write quakea8.atr
make.bat           :: build-a8.bat, then boot quakea8.atr in Altirra
run-game.bat       :: boot quakea8.atr in Altirra
run-editor.bat     :: local map / skeleton / item editor
```

Controls: joystick to move and fire. Button 2 strafes. Enable an ST mouse in Options to turn and shoot.
