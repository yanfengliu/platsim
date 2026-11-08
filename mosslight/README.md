# Mosslight

A small colony in a living cavern. Mark rock to dig, give four survivors construction jobs, and grow a habitat around food, breathable air, and power. This is the first playable prototype, maintained in the dedicated `yanfengliu/platsim` repository.

## Open in Godot

Use the standard GDScript edition of [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/). Import this folder's `project.godot`, open it, and press F6 to run the main scene or F5 to run the project. The Compatibility renderer is selected for native desktop and web support. No asset-store downloads, plugins, accounts, or runtime network calls are needed.

The editor and exported game support Windows, Linux, and macOS. The macOS export preset uses a universal binary for Intel and Apple Silicon. Native macOS execution must be checked on a Mac; a successful Windows-side export does not establish that runtime result. The prototype's Mac build uses ad-hoc signing, not Apple notarization; direct-download distribution may require the recipient to explicitly allow it in macOS Privacy & Security settings.

## Play

Choose **Enter the hollow** on the title screen. Dig into the cave, provide lit growing spaces, and keep supplies coming while working toward the beacon objective. Hover or select a tile to inspect it; buildings explain missing resources and inactive conditions. Complete the chapter by surviving five days (20 minutes at 1x, about seven at 3x), with healthy surviving settlers, renewable food and water, healthy air, and a powered beacon maintained for two minutes. Generator fuel still needs gathering from deposits; the chapter objective does not promise endless power.

The on-screen help lists the current keyboard and mouse controls. Space pauses; 1x and 3x buttons change speed; the air overlay explains room conditions. Construction costs are shown before placement. A new expedition starts a fresh colony. Live-game saving is outside this first prototype's scope.

Press Escape or choose Menu to pause the action and open Settings or Help. Escape backs out through those screens and returns to your previous play or pause state. Settings enlarges text, buttons, and spacing; the available scale choices depend on window size, and the displayed limit keeps controls reachable. Reset returns to 100%. Settings last for the current session. Settler movement is drawn smoothly between simulation updates without changing job timing or survival rules.

For a gentle first expedition, add mushrooms and an airfern beside the existing glow lamp in Lantern Hollow. Dig the ore plug below the central ladder, then extend that ladder three tiles down into Root Quarry. Gather its ore and the root deposit for generator fuel before building the beacon near the lamp. The upper roost, middle ledge, hollow, and quarry are connected by real walking and climbing routes.

| Action | Controls |
| --- | --- |
| Select inspection / digging | 0 / 1 |
| Select ladder / bed / mushrooms / airfern | 2 / 3 / 4 / 5 |
| Select lamp / generator / cistern / beacon | 6 / 7 / 8 / 9 |
| Use selected tool | Left click; drag with Dig to mark multiple tiles |
| Move tile cursor / use tool from keyboard | Arrow keys / Enter |
| Cancel a queued job | X, then click its tile or press Enter |
| Return to inspection | 0 or right click |
| Open menu / go back | Escape |
| Pause / show air / help | Space / V / H |
| Pan / zoom / center colony | WASD or middle drag / mouse wheel / Home |
| Navigate buttons | Tab and Shift+Tab, then Enter |

## Verify and export

From the repository root, use Node 24 and point `GODOT_BIN` at your Godot executable. If the executable is named `godot` on PATH, the variable is optional. Install matching export templates in Godot for exports, or set `GODOT_TEMPLATES` to a folder holding the unpacked official `web_nothreads_debug.zip`, `web_nothreads_release.zip`, `macos.zip`, `windows_debug_x86_64.exe`, and `windows_release_x86_64.exe` files. The helper validates only the templates needed by each selected export.

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
node mosslight/tools/godot.mjs import
node mosslight/tools/godot.mjs test
node mosslight/tools/godot.mjs export-web
node mosslight/tools/godot.mjs export-windows
node mosslight/tools/godot.mjs export-macos
```

`test` runs the simulation, motion-presentation, digging-animation, UI-settings, and terrain-cache checks. `verify` runs import, those five suites, and web export together. `--out <path>` overrides an export's output file. Exports use an isolated temporary copy of the Godot project, so task-local template paths are never written to tracked presets. Temporary staging is removed even after an export failure. Godot is run headlessly, with hidden Windows child processes and a bounded timeout. CI repeats import and all five suites with a checksum-pinned Godot runtime. Native frame pacing and motion need a real GPU-rendered run; headless Godot uses a dummy renderer and cannot establish that result.

Web output is written under ignored `output/mosslight-web/`; Windows and Mac artifacts go under ignored `output/mosslight-desktop/`. Launch `Mosslight.exe` on Windows, or unzip the Mac archive and open its `.app` on macOS. Serve the web output over localhost rather than opening its HTML as a file:

```sh
node mosslight/tools/serve.mjs
```

Open [localhost:4180](http://127.0.0.1:4180). Stop the server with Ctrl+C. The web build uses one thread and needs no cross-origin-isolation headers. Browser acceptance uses real keyboard/mouse actions and inspected screenshots; simulation tests alone cannot verify the rendered controls.
