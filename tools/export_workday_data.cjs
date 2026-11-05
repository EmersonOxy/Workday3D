// Authoring tool: converts original data into JSON. Not part of the game runtime.
const fs = require('fs'), vm = require('vm'), path = require('path');
const base = process.argv[2] || '.godot/workday-source/src/js';
const ctx = vm.createContext({console, APP_ICO:{}, load:(_k,d)=>d, save:()=>{}, BAL_KEYS:[], document:{getElementById:()=>null}, CAST:{}, CAST_ORDER:[], SOC_THREADS:{}, SOC_MEM:{}, SOC_PROMISE:{}});
ctx.castAdd = d => {ctx.CAST[d.id]=d;ctx.CAST_ORDER.push(d.id)};
ctx.socThreads = a => a.forEach(t=>ctx.SOC_THREADS[t.id]={by:'npc',prio:50,ttl:2,start:'a',...t});
ctx.socMem = o => Object.assign(ctx.SOC_MEM,o);
function run(file,cut){let s=fs.readFileSync(path.join(base,file),'utf8');if(cut)s=s.slice(0,s.indexOf(cut));vm.runInContext(s,ctx,{filename:file});}
run('00-cabecalho.js');run('01-textos-por-idioma.js');run('52-progressao.js');run('shared/55-decor-extra.js');run('02-mecanica.js');
const uiSource=fs.readFileSync(path.join(base,'09-telas.js'),'utf8');
const icons=uiSource.slice(uiSource.indexOf('const APP_ICO ='),uiSource.indexOf('// Calculadora:'));
vm.runInContext(icons.replace('const APP_ICO =','APP_ICO ='),ctx);
run('40-eventos.js','const QST =');
run('shared/10-palette.js');run('shared/30-sprites.js');run('44-social-elenco.js');run('45-social-conversas.js');run('32-minigames.js');run('32g-painting.js');
const payload=vm.runInContext('({languages:LANGS,sprites:SPR2,app_icons:APP_ICO,palette:WD_PAL,artworks:ARTWORKS,paint_palette:PAINT_PALETTE,rhythm:RHY,ship:SHIP,difficulties:DIFFS,debut:DEBUT,shop:SHOP,perks:PERK_IDS,special:SPECIAL,cycle:CYCLE,locked:LOCKED,pins:PIN_SPR,cast:CAST,threads:SOC_THREADS,memories:SOC_MEM,promises:SOC_PROMISE})',ctx);
// Explicitly retain function declarations for the port inventory; Godot does not execute JS.
fs.writeFileSync('assets/data/workday_original.json',JSON.stringify(payload,(_k,v)=>typeof v==='function'?{source_function:String(v)}:v,2));
console.log('Exported original texts, balance, events and '+Object.keys(payload.threads).length+' conversations.');



