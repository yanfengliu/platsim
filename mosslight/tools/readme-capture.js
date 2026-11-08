// Run with Playwright CLI's run-code --filename after opening a fresh web build.
// This is ordinary keyboard/mouse gameplay; the published snapshot is read-only.
async (page) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  const snapshot = () => page.evaluate(() => window.__MOSSLIGHT_SNAPSHOT__);
  const press = async key => { await page.keyboard.press(key); await page.waitForTimeout(100); };
  const click = async name => {
    await page.waitForTimeout(350);
    const state = await snapshot(), control = state.controls[name];
    if (!control?.visible || control.disabled) throw new Error(`Unavailable control: ${name}`);
    await page.mouse.click(control.clip.x + control.clip.width / 2, control.clip.y + control.clip.height / 2);
    await page.waitForTimeout(200);
  };
  const mark = async (key, x, y) => {
    if (key === 'farm' || key === 'airfern') {
      await press('b');
      if ((await snapshot()).build_menu.category) await click('build_back');
      await click('category_life_support');
      await click('tool_' + key);
    } else await press(key);
    const state = await snapshot();
    for (let i = 0; i < Math.abs(x - state.cursor.x); i++) await page.keyboard.press(x > state.cursor.x ? 'ArrowRight' : 'ArrowLeft');
    for (let i = 0; i < Math.abs(y - state.cursor.y); i++) await page.keyboard.press(y > state.cursor.y ? 'ArrowDown' : 'ArrowUp');
    await press('Enter');
  };
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.reload();
  await page.waitForFunction(() => window.__MOSSLIGHT_SNAPSHOT__?.overlay === 'title', null, { timeout: 60000 });
  await click('start');
  await press('Space');
  await mark('farm', 21, 16);
  await mark('airfern', 22, 16);
  await mark('1', 18, 20);
  if ((await snapshot()).jobs.length !== 3) throw new Error('Representative colony jobs were not queued.');
  await click('speed_3');
  await press('Space');
  await page.waitForFunction(() => {
    const state = window.__MOSSLIGHT_SNAPSHOT__;
    return state.buildings.some(b => b.kind === 'farm' && b.x === 21 && b.y === 16)
      && state.buildings.some(b => b.kind === 'airfern' && b.x === 22 && b.y === 16)
      && state.jobs.length === 0;
  }, null, { timeout: 60000 });
  await press('Space');
  await mark('1', 17, 15);
  await click('speed_1');
  await press('Space');
  await page.waitForFunction(() => window.__MOSSLIGHT_SNAPSHOT__.jobs.some(j => j.kind === 'dig' && j.x === 17 && j.y === 15 && j.progress > 0), null, { timeout: 45000 });
  await press('Space');
  await press('Home');
  await page.mouse.move(10, 10);
  await page.waitForTimeout(350);
  const state = await snapshot();
  if (state.overlay || !state.paused || state.status !== 'playing' || state.colonists.filter(c => c.alive).length !== 4) throw new Error('Capture is not a healthy live colony.');
  if (errors.length) throw new Error(errors.join('\n'));
  await page.screenshot({ path: 'gameplay-candidate.jpg', type: 'jpeg', quality: 85 });
  return { elapsed: state.elapsed, buildings: state.buildings.length, jobs: state.jobs, viewport: state.viewport };
}
