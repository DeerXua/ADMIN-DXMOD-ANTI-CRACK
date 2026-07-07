import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const INPUT_FILE = path.join(__dirname, 'protected_payload.lua');
const SRC_DIR = path.join(__dirname, 'src');

if (!fs.existsSync(SRC_DIR)) {
  fs.mkdirSync(SRC_DIR, { recursive: true });
}

const content = fs.readFileSync(INPUT_FILE, 'utf8');
const lines = content.split('\r\n'); // Handle CRLF or LF properly
const cleanLines = lines.length === 1 ? content.split('\n') : lines;

console.log(`Total lines: ${cleanLines.length}`);

// We will scan for:
// "-- =========================== PHẦN 30: CÁC HÀM GỐC CÒN LẠI ==========================="
// "-- =========================== PHẦN 31: INIT ALL MOD SYSTEMS ==========================="

let part30Index = -1;
let part31Index = -1;

for (let i = 0; i < cleanLines.length; i++) {
  const line = cleanLines[i];
  if (line.includes('PHẦN 30: CÁC HÀM GỐC CÒN LẠI')) {
    part30Index = i;
  }
  if (line.includes('PHẦN 31: INIT ALL MOD SYSTEMS')) {
    part31Index = i;
  }
}

console.log(`Part 30 starts at line: ${part30Index + 1}`);
console.log(`Part 31 starts at line: ${part31Index + 1}`);

if (part30Index === -1 || part31Index === -1) {
  console.error('Error: Could not find section headers in protected_payload.lua');
  process.exit(1);
}

const coreLines = cleanLines.slice(0, part30Index);
const originalLines = cleanLines.slice(part30Index, part31Index);
const footerLines = cleanLines.slice(part31Index);

fs.writeFileSync(path.join(SRC_DIR, 'core_payload.lua'), coreLines.join('\n'), 'utf8');
fs.writeFileSync(path.join(SRC_DIR, 'original_functions.lua'), originalLines.join('\n'), 'utf8');
fs.writeFileSync(path.join(SRC_DIR, 'footer.lua'), footerLines.join('\n'), 'utf8');

console.log('Splitting completed successfully!');
