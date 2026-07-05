import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SRC_DIR = path.join(__dirname, 'src');
const OUTPUT_FILE = path.join(__dirname, 'protected_payload.lua');

function build() {
  console.log('[BUILD] Starting build of protected_payload.lua...');
  const files = [
    path.join(SRC_DIR, 'core_payload.lua'),
    path.join(SRC_DIR, 'original_functions.lua'),
    path.join(SRC_DIR, 'footer.lua')
  ];

  let combined = '';
  for (const file of files) {
    if (!fs.existsSync(file)) {
      console.error(`[BUILD] Error: File not found: ${file}`);
      process.exit(1);
    }
    combined += fs.readFileSync(file, 'utf8') + '\n';
  }

  fs.writeFileSync(OUTPUT_FILE, combined, 'utf8');
  console.log(`[BUILD] Successfully built protected_payload.lua (${(combined.length / 1024).toFixed(2)} KB)`);
}

build();
