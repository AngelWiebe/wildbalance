# WildBalance

WildBalance is a Godot 4.7 ecosystem-stewardship game backed by a Go WebSocket simulation. You manage a forest's herd, wolf pack, meadow health, and seasonal pressure while observing the animals in a 3D forest.

## Run locally

1. Install **Godot 4.7.x** and **Go 1.23+**.
2. Start the simulation:

   ```sh
   cd server
   go run .
   ```

   The server listens at `ws://127.0.0.1:8080/ws`.
3. Import `godot/project.godot` in Godot and press **F5**.
4. Press **Enter** or **Space** at the opening screen to begin a run.

## Stewardship goal

Balance the ecosystem through four seasons. To clear a season, you must:

- Keep ecosystem health above 70% for 60 seconds.
- Reseed at least two different meadows.
- Work within a budget of **three reseeds per season**.

The balance score considers herd size, wolf-pack pressure, and meadow food. A healthy reference point is about **four deer and two wolves**. Too many deer consume the meadows; too few deer or too much predator pressure also destabilize the forest.

## Controls

| Control | Action |
| --- | --- |
| `1`–`8` | Reseed a meadow (three per season; 8-second cooldown) |
| `-` / `=` | Decrease / increase herd target (2–6 deer) |
| `[` / `]` | Decrease / increase pack target (1–2 wolves) |
| `Q` | Scare a hunting wolf (18-second cooldown) |
| `T` | Start a new run |
| `WASD` | Pan the orbit view |
| Right-drag | Look around |
| Scroll | Zoom; adjusts speed in free-fly |
| `V` | Toggle free-fly mode |
| `Space` / `Shift` | Rise / descend in free-fly mode |
| `F` | Follow a deer |
| `R` | Reset the camera |
| `H` | Hide the HUD |

## Simulation notes

- The server sends simulation snapshots to Godot at 10 Hz.
- Deer graze, flee local hunts, and periodically rest. The wolf chooses prey from the full herd.
- A one-wolf pack is deliberately slower and less aggressive than a two-wolf pack.
- The ecosystem director manages recovery and seasonal conditions until you take over population targets; the HUD then shows `STEWARD • HERD X • PACK X`.

## Project layout

```text
godot/     Godot project, forest scene, scripts, and 3D assets
server/    Go ecosystem simulation and WebSocket server
```
