import fs from 'fs';
import path from 'path';
import * as babel from '@babel/core';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const htmlPath = path.join(__dirname, 'public', 'index.html');
const htmlContent = fs.readFileSync(htmlPath, 'utf8');

const scriptMatch = htmlContent.match(/<script\s+type="text\/babel">([\s\S]*?)<\/script>/);
if (!scriptMatch) {
  console.log("[COMPILE] No JSX block found in index.html (already compiled).");
  process.exit(0);
}

const jsxCode = scriptMatch[1];
const appJsPath = path.join(__dirname, 'public', 'app.min.js');

console.log("[COMPILE] Compiling JSX to pure JS via @babel/core...");
const result = babel.transformSync(jsxCode, {
  presets: ['@babel/preset-react']
});

fs.writeFileSync(appJsPath, result.code, 'utf8');
console.log(`[COMPILE] public/app.min.js generated successfully (${(result.code.length / 1024).toFixed(1)} KB)!`);

let cleanHtml = htmlContent;
cleanHtml = cleanHtml.replace(/<script\s+src="https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/babel-standalone\/[^"]+"><\/script>\s*/gi, '');
cleanHtml = cleanHtml.replace(/<script\s+src="https:\/\/unpkg\.com\/@babel\/standalone\/[^"]+"><\/script>\s*/gi, '');
cleanHtml = cleanHtml.replace(/<script\s+type="text\/babel">[\s\S]*?<\/script>/gi, '<script src="/app.min.js"></script>');

fs.writeFileSync(htmlPath, cleanHtml, 'utf8');
console.log("[COMPILE] public/index.html updated to use app.min.js!");
