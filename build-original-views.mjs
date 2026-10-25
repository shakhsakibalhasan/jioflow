import {readFile,writeFile} from 'node:fs/promises';
const files=['app.js','auth.js','insights.js','layout.js','workspaces.js','creator.js','refinements.js'];
const source=(await Promise.all(files.map(f=>readFile(f,'utf8')))).join('\n');
const adapter=await readFile('original-view-adapter.txt','utf8');
await writeFile('original-views.js',`// Retained original screens. Isolated storage; no demo bootstrap or local persistence.\n(function(){\nconst globalThis=Object.create(window);globalThis.__JIOFLOW_TEST__=true;\nconst localStorage={getItem:()=>null,setItem:()=>{},removeItem:()=>{}},sessionStorage={getItem:()=>null,setItem:()=>{},removeItem:()=>{}};\n${source}\n${adapter}\n})();\n`);
