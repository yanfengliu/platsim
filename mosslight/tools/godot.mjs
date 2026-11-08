import { spawn } from 'node:child_process';
import { cp, mkdir, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repository = path.dirname(project);
const engine = process.env.GODOT_BIN || 'godot';
const command = process.argv[2] || 'verify';
const outputArgument = process.argv.indexOf('--out');
const requestedOutput = outputArgument < 0 ? null : process.argv[outputArgument + 1];
if (outputArgument >= 0 && !requestedOutput) throw new Error('--out needs an output path');
const exports = {
  'export-web': ['Web', 'mosslight-web/index.html'],
  'export-macos': ['macOS', 'mosslight-desktop/Mosslight-macOS.zip'],
  'export-windows': ['Windows Desktop', 'mosslight-desktop/Mosslight.exe'],
};

async function run(args) {
  const logDirectory = path.join(repository, 'output', 'mosslight-checks');
  await mkdir(logDirectory, { recursive: true });
  const logPath = path.join(logDirectory, `godot-${process.pid}-${Date.now()}.log`);
  console.log(`Godot ${args.join(' ')}`);
  await new Promise((resolve, reject) => {
    const child = spawn(engine, ['--log-file', logPath, ...args], { cwd: repository, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    let failed = false;
    let timedOut = false;
    const inspect = chunk => {
      const text = chunk.toString();
      if (/(?:SCRIPT ERROR|Parse Error|Failed to load script|ERROR:)/.test(text)) failed = true;
      process.stdout.write(text);
    };
    child.stdout.on('data', inspect);
    child.stderr.on('data', inspect);
    const terminate = () => {
      if (process.platform === 'win32') {
        const killer = spawn('taskkill', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
        killer.on('error', () => child.kill());
      } else child.kill('SIGTERM');
    };
    const timer = setTimeout(() => { timedOut = true; terminate(); }, 180_000);
    const interrupt = () => terminate();
    process.once('SIGINT', interrupt);
    process.once('SIGTERM', interrupt);
    const cleanup = () => {
      clearTimeout(timer);
      process.off('SIGINT', interrupt);
      process.off('SIGTERM', interrupt);
    };
    child.on('error', error => { cleanup(); reject(new Error(`Cannot run ${engine}: ${error.message}. Set GODOT_BIN to your Godot executable.`)); });
    child.on('close', code => {
      cleanup();
      if (code !== 0 || failed || timedOut) reject(new Error(`Godot failed (exit ${code}, script/error output ${failed}, timeout ${timedOut})`));
      else resolve();
    });
  });
  await rm(logPath, { force: true });
}

async function importProject(directory = project) {
  await run(['--headless', '--path', directory, '--editor', '--import']);
}

async function exportProject(kind) {
  const [preset, defaultRelative] = exports[kind];
  const output = path.resolve(requestedOutput || path.join(repository, 'output', defaultRelative));
  await mkdir(path.dirname(output), { recursive: true });
  const stagingRoot = path.join(repository, 'tmp');
  await mkdir(stagingRoot, { recursive: true });
  const staging = await mkdtemp(path.join(stagingRoot, 'mosslight-export-'));
  try {
    await cp(project, staging, {
      recursive: true,
      filter: source => !['.godot', 'tools', 'tests', 'README.md'].includes(path.basename(source)),
    });
    if (process.env.GODOT_TEMPLATES) {
      const templates = path.resolve(process.env.GODOT_TEMPLATES);
      const templateNames = [
        ['web_nothreads_debug.zip', 'web_nothreads_release.zip'],
        ['macos.zip', 'macos.zip'],
        ['windows_debug_x86_64.exe', 'windows_release_x86_64.exe'],
      ];
      let config = await readFile(path.join(staging, 'export_presets.cfg'), 'utf8');
      let index = -1;
      config = config.replace(/custom_template\/debug=""\r?\ncustom_template\/release=""/g, () => {
        index++;
        return ['debug', 'release'].map((mode, n) => `custom_template/${mode}=${JSON.stringify(path.join(templates, templateNames[index][n]).replaceAll('\\', '/'))}`).join('\n');
      });
      const exportIndex = Object.keys(exports).indexOf(kind);
      for (const name of templateNames[exportIndex]) await stat(path.join(templates, name));
      await writeFile(path.join(staging, 'export_presets.cfg'), config);
    }
    await importProject(staging);
    await run(['--headless', '--path', staging, '--export-release', preset, output]);
    if ((await stat(output)).size === 0) throw new Error('Export produced an empty artifact');
    if (kind === 'export-web') {
      for (const extension of ['.js', '.wasm', '.pck']) await stat(output.replace(/\.html$/, extension));
    }
    console.log(`Export ready: ${output}`);
  } finally {
    await rm(staging, { recursive: true, force: true });
  }
}

async function testProject() {
  for (const test of ['simulation_test.gd', 'presentation_motion_test.gd', 'ui_settings_test.gd', 'terrain_cache_test.gd']) {
    await run(['--headless', '--path', project, '--script', `res://tests/${test}`]);
  }
}

if (command === 'import') await importProject();
else if (command === 'test') await testProject();
else if (Object.hasOwn(exports, command)) await exportProject(command);
else if (command === 'verify') {
  await importProject();
  await testProject();
  await exportProject('export-web');
} else throw new Error(`Unknown command ${command}. Use import, test, verify, export-web, export-windows, or export-macos.`);
