import puppeteer from "puppeteer";
import { puppeteerConfig } from "../puppeteer.config";
import * as fs from "fs";
import * as path from "path";

interface PerformanceMetrics {
  page: string;
  url: string;
  timestamp: string;
  metrics: {
    domContentLoaded: number;
    load: number;
    firstPaint: number | null;
    firstContentfulPaint: number | null;
    domNodes: number;
    jsHeapUsedSize: number;
  };
}

async function runPerformanceAudit() {
  const reportDir = path.resolve( __dirname, "..", puppeteerConfig.reportDir );
  if ( !fs.existsSync( reportDir ) ) {
    fs.mkdirSync( reportDir, { recursive: true } );
  }

  const browser = await puppeteer.launch( {
    headless: puppeteerConfig.headless,
    slowMo: puppeteerConfig.slowMo,
    defaultViewport: puppeteerConfig.defaultViewport
  } );

  const results: PerformanceMetrics[] = [];

  for ( const pageConfig of puppeteerConfig.pages ) {
    const page = await browser.newPage();
    const url = `${puppeteerConfig.baseUrl}${pageConfig.path}`;

    console.log( `Auditing: ${pageConfig.name} (${url})` );

    await page.goto( url, { waitUntil: "networkidle2", timeout: 30_000 } );

    const performanceTiming = await page.evaluate( () => {
      const timing = performance.timing;
      return {
        domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
        load: timing.loadEventEnd - timing.navigationStart
      };
    } );

    const paintEntries = await page.evaluate( () => {
      const entries = performance.getEntriesByType( "paint" );
      return entries.map( e => ( { name: e.name, startTime: e.startTime } ) );
    } );

    const firstPaint = paintEntries.find( e => e.name === "first-paint" );
    const fcp = paintEntries.find( e => e.name === "first-contentful-paint" );

    const metrics = await page.metrics();
    const domNodes = await page.evaluate( () => document.querySelectorAll( "*" ).length );

    results.push( {
      page: pageConfig.name,
      url,
      timestamp: new Date().toISOString(),
      metrics: {
        domContentLoaded: performanceTiming.domContentLoaded,
        load: performanceTiming.load,
        firstPaint: firstPaint?.startTime ?? null,
        firstContentfulPaint: fcp?.startTime ?? null,
        domNodes,
        jsHeapUsedSize: metrics.JSHeapUsedSize || 0
      }
    } );

    await page.close();
  }

  await browser.close();

  const reportPath = path.join( reportDir, `performance-${Date.now()}.json` );
  fs.writeFileSync( reportPath, JSON.stringify( results, null, 2 ) );
  console.log( `\nPerformance report saved to: ${reportPath}` );

  console.log( "\n--- Performance Summary ---" );
  for ( const result of results ) {
    console.log( `\n${result.page}:` );
    console.log( `  DOM Content Loaded: ${result.metrics.domContentLoaded}ms` );
    console.log( `  Full Load: ${result.metrics.load}ms` );
    console.log( `  First Contentful Paint: ${result.metrics.firstContentfulPaint ?? "N/A"}ms` );
    console.log( `  DOM Nodes: ${result.metrics.domNodes}` );
    console.log( `  JS Heap: ${( result.metrics.jsHeapUsedSize / 1024 / 1024 ).toFixed( 1 )}MB` );
  }
}

runPerformanceAudit().catch( err => {
  console.error( "Performance audit failed:", err );
  process.exit( 1 );
} );
