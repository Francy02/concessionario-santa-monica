import { chromium } from '@playwright/test';
import { existsSync } from 'node:fs';
import assert from 'node:assert/strict';
const local='C:/Users/Francesco/AppData/Local/ms-playwright/chromium-1208/chrome-win64/chrome.exe';
const executablePath=process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH||(existsSync(local)?local:undefined);
const browser=await chromium.launch({executablePath,headless:true});
const page=await browser.newPage({viewport:{width:1440,height:1080}});const errors=[];
page.on('pageerror',e=>errors.push(e.message));
try{
await page.goto('http://127.0.0.1:5173/?demo=1');await page.getByRole('heading',{name:'Ciao, Alex.'}).waitFor();await page.evaluate(()=>document.fonts.ready);
await page.screenshot({path:'docs/dashboard-desktop.png',fullPage:true});
await page.getByRole('button',{name:'Timbra entrata',exact:true}).click();await page.getByRole('button',{name:'Timbra uscita',exact:true}).waitFor();await page.getByRole('button',{name:'Timbra uscita',exact:true}).click();
await page.getByRole('button',{name:'Nuova vendita',exact:true}).click();
await page.getByLabel('Veicolo',{exact:true}).fill('Test Comet');await page.getByLabel('Nome cliente RP').fill('Test Cliente');await page.getByLabel('Prezzo di vendita').fill('100000');await page.getByLabel('Costo del veicolo').fill('70000');await page.getByRole('button',{name:'Salva',exact:true}).click();
await page.locator('.sidebar').getByRole('button',{name:'Vendite',exact:true}).click();await page.getByRole('textbox',{name:'Cerca vendite'}).fill('Test Comet');assert.equal(await page.locator('tbody tr').count(),1);
page.on('dialog',dialog=>dialog.accept());await page.getByRole('button',{name:'Annulla',exact:true}).click();await page.getByText('Annullata',{exact:true}).waitFor();
await page.locator('.sidebar').getByRole('button',{name:'Cassa',exact:true}).click();await page.getByRole('button',{name:'Movimento',exact:true}).click();await page.getByLabel('Importo').fill('1000');await page.getByLabel('Descrizione').fill('Spese test');await page.getByRole('button',{name:'Salva',exact:true}).click();await page.getByText('Spese test',{exact:true}).waitFor();
await page.locator('.sidebar').getByRole('button',{name:'Il team',exact:true}).click();await page.getByRole('button',{name:'Aggiungi dipendente'}).click();await page.getByLabel('ID Discord',{exact:true}).fill('123456789012345678');await page.getByLabel('Nome RP').fill('Nuovo Collega');await page.getByRole('button',{name:'Salva',exact:true}).click();await page.getByRole('heading',{name:'Nuovo Collega'}).waitFor();
await page.locator('.sidebar').getByRole('button',{name:'Panoramica',exact:true}).click();
await page.setViewportSize({width:390,height:844});await page.screenshot({path:'docs/dashboard-mobile.png',fullPage:true,animations:'disabled'});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Mobile overflow');
await page.getByRole('button',{name:'Apri navigazione'}).click();await page.locator('.sidebar').getByRole('button',{name:'Vendite',exact:true}).click();assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Mobile table overflow');
await page.getByRole('button',{name:'Nuova vendita',exact:true}).click();await page.getByRole('button',{name:'Chiudi finestra'}).click();
await page.goto('http://127.0.0.1:5173/');await page.getByRole('button',{name:'Accedi con Discord'}).waitFor();await page.setViewportSize({width:1440,height:1000});await page.screenshot({path:'docs/login-desktop.png',fullPage:true});
assert.deepEqual(errors,[]);console.log('PASS: demo clock in/out, sale, reversal, cash, members, desktop and mobile layouts, login, no runtime errors.');
}finally{await browser.close()}
