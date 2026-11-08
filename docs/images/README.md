# Keeping the gameplay image current

The root README uses `gameplay.jpg`. Show the current game at its best: readable resource controls, the pixel-art cave, settlers, buildings and active work. Use an actual rendered game capture. Keep it at least 960 x 540 and below 512 KiB; 1440 x 900 JPEG at quality 85 works well. Inspect the full image before accepting it, and revise the scene or framing as the game evolves.

`gameplay.json` binds the image bytes to a digest of the game source, scenes, project/export settings and artwork. Text line endings are normalized across Windows and CI. Tests, tooling, documentation and generated caches are excluded. `npm run readme:check`, included in `npm run check` and CI, fails if either the source or image no longer matches. It checks freshness, not visual quality; maintainers still inspect the capture. Do not update the manifest without taking a new picture of the current build.

## Refresh

1. Run `npm run build` with the matching Godot web templates installed, then `npm run dev`. This creates and serves the current web export at localhost:4180.
2. Use an isolated, headless [Playwright CLI](https://github.com/microsoft/playwright-cli) session, or play normally and take a screenshot. Playwright is a development capture tool, not a game dependency. The supplied recipe was verified with CLI 0.1.23 and Chrome.
3. For the repeatable scene, run the following from an ignored scratch directory such as `output/playwright/readme`. Replace `<repo>` with the absolute repository path. Godot draws into a canvas, so the recipe reads published control bounds and uses real keyboard/mouse actions; it does not alter the simulation through debug state.

```sh
playwright-cli -s=mosslight-readme open http://127.0.0.1:4180
playwright-cli -s=mosslight-readme run-code --filename=<repo>/mosslight/tools/readme-capture.js
playwright-cli -s=mosslight-readme close
```

The recipe starts a fresh colony, adds mushrooms and an airfern near the lamp, opens the quarry plug, and pauses a real excavation. It saves `gameplay-candidate.jpg` in the CLI working directory. If gameplay or layout changes invalidate the recipe, adapt the actions and choose a new representative scene instead of bypassing its checks.

4. Inspect the image at full resolution, then from the repository root run:

```sh
npm run readme:image -- output/playwright/readme/gameplay-candidate.jpg
npm run readme:check
```

5. Update the root README caption if the pictured scene changed. Commit `docs/images/gameplay.jpg` and `docs/images/gameplay.json` with the game change. Close the named browser in a `finally` cleanup path if scripting the sequence, stop the localhost server, and remove task-owned scratch captures and CLI state after preserving any needed verification evidence. Never close unrelated browser sessions.

This workflow requires a fresh, reviewed image alongside relevant code changes. It does not schedule unattended screenshots or add a bot that writes commits.
