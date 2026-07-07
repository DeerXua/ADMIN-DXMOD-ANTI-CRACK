import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const STUB_PATH = 'C:/ExtractedPak/TOOL PAK DX/REPACK/LUA_MODDED/BRPlayerCharacterBase.lua';
const SRC_DIR = path.join(__dirname, 'src');
const ORIGINAL_FUNCTIONS_PATH = path.join(SRC_DIR, 'original_functions.lua');
const OUTPUT_FILE = path.join(__dirname, 'protected_payload.lua');

function sync() {
  console.log('[SYNC] Reading stub file:', STUB_PATH);
  if (!fs.existsSync(STUB_PATH)) {
    console.error('[SYNC] Error: Stub file does not exist at:', STUB_PATH);
    process.exit(1);
  }

  const stubContent = fs.readFileSync(STUB_PATH, 'utf8');
  
  // Find start: first occurrence of "function BRPlayerCharacterBase:" or "function BRPlayerCharacterBase.ctor"
  const startMatch = stubContent.match(/function\s+BRPlayerCharacterBase\s*:\s*\w+/);
  if (!startMatch) {
    console.error('[SYNC] Error: Could not find start of original functions in stub.');
    process.exit(1);
  }
  const startIndex = startMatch.index;

  // Find end: local function GetDeviceUID or the loader start comment
  const endMatch = stubContent.match(/local\s+function\s+GetDeviceUID/);
  const endCommentMatch = stubContent.match(/--\s*\[DXMOD\]\s*SECURE\s*CLIENT\s*LOADER/);
  
  let endIndex = -1;
  if (endCommentMatch) {
    endIndex = endCommentMatch.index;
  } else if (endMatch) {
    endIndex = endMatch.index;
  } else {
    console.error('[SYNC] Error: Could not find end of original functions in stub.');
    process.exit(1);
  }

  console.log(`[SYNC] Extracting lines from character index ${startIndex} to ${endIndex}...`);
  let originalFunctions = stubContent.substring(startIndex, endIndex).trim();
  
  // Tự động inject bypass chống khựng khi rơi (NO_LANDING_LAG) vào OnLanded
  const onLandedRegex = /function\s+BRPlayerCharacterBase\s*:\s*OnLanded\s*\(\s*\)\s*([\s\S]*?)if\s+self\.HandleOnLanded\s+then\s+self\s*:\s*HandleOnLanded\s*\(\s*-1\s*\)\s*end/i;
  const newOnLanded = `function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if _G.HK_GetVal("NO_LANDING_LAG") == 1 then
    pcall(function()
      if slua.isValid(self.Mesh) then
        local animIns = self.Mesh:GetAnimInstance()
        if slua.isValid(animIns) then
          animIns:Montage_Stop(0.0)
        end
      end
      if slua.isValid(self.STCharacterMovement) then
        local EMovementMode = import("EMovementMode")
        self.STCharacterMovement:SetMovementMode(EMovementMode.MOVE_Walking)
        local velocity = self:GetVelocity()
        if velocity then
          velocity.Z = 0
        end
      end
    end)
  else
    if self.HandleOnLanded then
      self:HandleOnLanded(-1)
    end
  end`;
  originalFunctions = originalFunctions.replace(onLandedRegex, newOnLanded);
  
  // Clean up any training commas or characters if needed, but substring should be clean
  // Add Section 30 header
  const header = '-- =========================== PHẦN 30: CÁC HÀM GỐC CÒN LẠI ===========================\n';
  const fullContent = header + originalFunctions + '\n';
  
  fs.writeFileSync(ORIGINAL_FUNCTIONS_PATH, fullContent, 'utf8');
  console.log('[SYNC] Successfully extracted and updated original functions in src/original_functions.lua');

  // Trigger rebuild
  console.log('[SYNC] Rebuilding final payload...');
  const files = [
    path.join(SRC_DIR, 'core_payload.lua'),
    ORIGINAL_FUNCTIONS_PATH,
    path.join(SRC_DIR, 'footer.lua')
  ];

  let combined = '';
  for (const file of files) {
    if (!fs.existsSync(file)) {
      console.error(`[SYNC BUILD] Error: File not found: ${file}`);
      process.exit(1);
    }
    combined += fs.readFileSync(file, 'utf8') + '\n';
  }

  fs.writeFileSync(OUTPUT_FILE, combined, 'utf8');
  console.log(`[SYNC BUILD] Successfully built protected_payload.lua (${(combined.length / 1024).toFixed(2)} KB)`);
}

sync();
