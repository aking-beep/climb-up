// Lets plain Node (22.6+, --experimental-strip-types) import the app's
// TypeScript: maps the `@/` alias to src/ and adds missing .ts extensions.
import { existsSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const SRC = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../src');

function candidate(base) {
  for (const ext of ['', '.ts', '.tsx', '/index.ts']) {
    if (existsSync(base + ext) && (ext !== '' || /\.(ts|tsx|js|mjs)$/.test(base))) return base + ext;
  }
  return null;
}

export async function resolve(specifier, context, next) {
  if (specifier.startsWith('@/')) {
    const found = candidate(path.join(SRC, specifier.slice(2)));
    if (found) return next(pathToFileURL(found).href, context);
  }
  if ((specifier.startsWith('./') || specifier.startsWith('../')) && context.parentURL?.startsWith('file:')) {
    const base = path.resolve(path.dirname(fileURLToPath(context.parentURL)), specifier);
    const found = candidate(base);
    if (found) return next(pathToFileURL(found).href, context);
  }
  return next(specifier, context);
}
