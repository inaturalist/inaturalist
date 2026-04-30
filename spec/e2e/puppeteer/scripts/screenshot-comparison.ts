import puppeteer from "puppeteer";
import { puppeteerConfig } from "../puppeteer.config";
import * as fs from "fs";
import * as path from "path";

async function captureScreenshots() {
  const screenshotDir = path.resolve( __dirname, "..", puppeteerConfig.screenshotDir );
  if ( !fs.existsSync( screenshotDir ) ) {
    fs.mkdirSync( screenshotDir, { recursive: true } );
  }

  const browser = await puppeteer.launch( {
    headless: puppeteerConfig.headless,
    slowMo: puppeteerConfig.slowMo,
    defaultViewport: puppeteerConfig.defaultViewport
  } );

  const timestamp = new Date().toISOString().replace( /[:.]/g, "-" );

  for ( const pageConfig of puppeteerConfig.pages ) {
    const page = await browser.newPage();
    const url = `${puppeteerConfig.baseUrl}${pageConfig.path}`;

    console.log( `Capturing: ${pageConfig.name} (${url})` );

    await page.goto( url, { waitUntil: "networkidle2", timeout: 30_000 } );

    // Wait a moment for any animations to settle
    await new Promise( resolve => setTimeout( resolve, 1000 ) );

    const filename = `${pageConfig.name}-${timestamp}.png`;
    const filepath = path.join( screenshotDir, filename );

    await page.screenshot( {
      path: filepath,
      fullPage: true
    } );

    console.log( `  Saved: ${filename}` );
    await page.close();
  }

  await browser.close();
  console.log( `\nAll screenshots saved to: ${screenshotDir}` );
}

captureScreenshots().catch( err => {
  console.error( "Screenshot capture failed:", err );
  process.exit( 1 );
} );
