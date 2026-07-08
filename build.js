import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PAYLOAD_FILE = path.join(__dirname, 'protected_payload.lua');

function validateLuaSource(file, content) {
  const trimmed = content.trimStart();
  const basename = path.basename(file);

  if (!trimmed) {
    console.error(`[BUILD] Error: ${basename} is empty.`);
    process.exit(1);
  }

  if (/^(429|403|404|500)\s*:/.test(trimmed) || /Too Many Requests|github\.com\/en\/site-policy/i.test(trimmed)) {
    console.error(`[BUILD] Error: ${basename} looks like an HTTP error page, not Lua source.`);
    process.exit(1);
  }
}

function build() {
  console.log('[BUILD] Checking protected_payload.lua...');

  if (!fs.existsSync(PAYLOAD_FILE)) {
    console.error(`[BUILD] Error: File not found: ${PAYLOAD_FILE}`);
    process.exit(1);
  }

  const content = fs.readFileSync(PAYLOAD_FILE, 'utf8');
  validateLuaSource(PAYLOAD_FILE, content);
  console.log(`[BUILD] protected_payload.lua is ready (${(content.length / 1024).toFixed(2)} KB)`);
}

build();
