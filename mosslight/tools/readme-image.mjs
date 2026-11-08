import { createHash } from 'node:crypto';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const directory = path.join(repository, 'docs/images');
const imagePath = path.join(directory, 'gameplay.jpg');
const manifestPath = path.join(directory, 'gameplay.json');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

async function sourceDigest() {
  const files = [];
  async function visit(relative) {
    for (const entry of await readdir(path.join(repository, relative), { withFileTypes: true })) {
      if (['.godot', 'tools', 'tests', 'exports'].includes(entry.name)) continue;
      const name = `${relative}/${entry.name}`;
      if (entry.isDirectory()) await visit(name);
      else if (entry.isFile() && !name.endsWith('.md')) files.push(name);
    }
  }
  await visit('mosslight');
  const digest = createHash('sha256');
  for (const name of files.sort()) {
    let bytes = await readFile(path.join(repository, name));
    // Git's Windows line-ending conversion must not invalidate the same source.
    if (/\.(gd|uid|tscn|godot|cfg|json|svg|import)$/.test(name)) {
      bytes = Buffer.from(bytes.toString('utf8').replaceAll('\r\n', '\n'));
    }
    digest.update(`${name}\0${bytes.length}\0`).update(bytes);
  }
  return digest.digest('hex');
}

function inspectImage(bytes) {
  if (bytes.length > 512 * 1024) throw new Error('README image exceeds the 512 KiB binary limit. Use JPEG quality 85 or lower.');
  if (bytes.readUInt16BE(0) !== 0xffd8) throw new Error('Use an actual gameplay JPEG capture.');
  for (let offset = 2; offset + 8 < bytes.length;) {
    if (bytes[offset] !== 0xff) break;
    const marker = bytes[offset + 1];
    const length = bytes.readUInt16BE(offset + 2);
    if (length < 2 || offset + 2 + length > bytes.length) break;
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      const height = bytes.readUInt16BE(offset + 5), width = bytes.readUInt16BE(offset + 7);
      if (width < 960 || height < 540) throw new Error('Capture at least 960 x 540 so gameplay and the HUD remain readable.');
      return { width, height };
    }
    offset += 2 + length;
  }
  throw new Error('JPEG dimensions could not be read.');
}

const command = process.argv[2];
if (command === 'update' && process.argv[3]) {
  const bytes = await readFile(path.resolve(process.argv[3]));
  const dimensions = inspectImage(bytes);
  const manifest = { sourceSha256: await sourceDigest(), imageSha256: hash(bytes), ...dimensions };
  await mkdir(directory, { recursive: true });
  await writeFile(imagePath, bytes);
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log('README image updated. Inspect it before committing both docs/images files.');
} else if (command === 'check') {
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const bytes = await readFile(imagePath);
  const dimensions = inspectImage(bytes);
  if (manifest.sourceSha256 !== await sourceDigest()) {
    throw new Error('README gameplay image is stale. Rebuild, capture current gameplay, then run npm run readme:image -- <capture.jpg>. See docs/images/README.md.');
  }
  if (manifest.imageSha256 !== hash(bytes) || manifest.width !== dimensions.width || manifest.height !== dimensions.height) {
    throw new Error('README image and capture manifest disagree. Run npm run readme:image -- <capture.jpg>.');
  }
  console.log(`README gameplay image is current (${dimensions.width} x ${dimensions.height}, ${bytes.length} bytes).`);
} else {
  throw new Error('Usage: node mosslight/tools/readme-image.mjs check | update <actual-gameplay.jpg>');
}
