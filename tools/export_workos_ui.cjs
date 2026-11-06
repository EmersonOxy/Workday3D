// Authoring tool: extracts the WorkOS pixel-art tables (start orb, menu/app icons, profile pictures, office sprites)
// from the original web game into assets/data/workos_ui.json. Not part of the game runtime.
// Usage: node tools/export_workos_ui.cjs <path to Workday/src/js>
const fs = require('fs'), vm = require('vm'), path = require('path');
const base = process.argv[2] || '../Workday/src/js';
const read = file => fs.readFileSync(path.join(base, file), 'utf8');

// Returns the literal that starts right after `marker` ({...} or [...]), matching brackets and skipping strings.
function literal(source, marker) {
  const start = source.indexOf(marker);
  if (start < 0) throw new Error('marker not found: ' + marker);
  let i = start + marker.length;
  while (source[i] !== '{' && source[i] !== '[') i++;
  const open = source[i], close = open === '{' ? '}' : ']';
  let depth = 0, quote = null;
  for (let j = i; j < source.length; j++) {
    const c = source[j];
    if (quote) { if (c === '\\') j++; else if (c === quote) quote = null; continue; }
    if (c === "'" || c === '"' || c === '`') { quote = c; continue; }
    if (c === open) depth++;
    else if (c === close && --depth === 0) return source.slice(i, j + 1);
  }
  throw new Error('unbalanced literal: ' + marker);
}

const ctx = vm.createContext({});
// Each table becomes a global in order, because later tables reference earlier ones (APP_ICO uses MENU_ICO).
const define = (name, text) => vm.runInContext(name + ' = (' + text + ')', ctx);
const telas = read('09-telas.js'), pixel = read('05-pixel-art.js'), events = read('40-eventos.js');
define('PAL', literal(pixel, 'const PAL ='));
define('SPR', literal(pixel, 'const SPR ='));
define('SPR2', literal(read('shared/30-sprites.js'), 'const SPR2 ='));
define('ORB_ICO', literal(telas, 'const ORB_ICO ='));
define('MENU_ICO', literal(telas, 'const MENU_ICO ='));
define('APP_ICO', literal(telas, 'const APP_ICO ='));
define('OS_PICS', literal(telas, 'const OS_PICS ='));
define('APP_ICO.arq', literal(events, 'APP_ICO.arq ='));
define('APP_ICO.shop', literal(events, 'APP_ICO.shop ='));
define('APP_ICO.msn', literal(read('44-social-elenco.js'), 'APP_ICO.msn ='));
const out = vm.runInContext('({orb: ORB_ICO, menu_icons: MENU_ICO, app_icons: APP_ICO, os_pics: OS_PICS, sprites: SPR, sprites2: SPR2, legacy_palette: PAL})', ctx);
fs.writeFileSync('assets/data/workos_ui.json', JSON.stringify(out));
console.log('WorkOS UI tables:', Object.entries(out).map(([k, v]) => k + '=' + Object.keys(v).length).join(', '));
