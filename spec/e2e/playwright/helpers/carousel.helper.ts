/// <reference types="node" />
import fs from "fs";
import path from "path";
import { expect, Page } from "@playwright/test";

const LONG_TITLE = "The Extraordinarily Long Named Community Biodiversity Survey of the Greater Metropolitan Watershed";
const PUBLIC_ASSETS = path.resolve( __dirname, "../../../../public/assets" );

function slideHtml( i: number, count: number ): string {
  return `
    <div class="Carousel-slide" role="group" aria-roledescription="slide" aria-label="${i + 1} of ${count}" data-carousel-slide>
      <div class="hero-labels">
        <span>New &amp; Noteworthy</span>
        <span class="in-progress">Event in progress</span>
      </div>
      <a class="photo" aria-label="${LONG_TITLE} ${i}" href="/projects/fixture-${i}" style="background-size: cover;"></a>
      <div class="project-caption">
        <h2><a class="title" href="/projects/fixture-${i}">${LONG_TITLE} ${i}</a></h2>
      </div>
    </div>
  `;
}

export function carouselHtml( count: number ): string {
  const indexes = Array.from( { length: count }, ( _, i ) => i );
  return `
    <div class="hero-feature Carousel" role="region" aria-roledescription="carousel" aria-label="Featured" data-carousel-root data-carousel-autoplay="5000">
      <div class="Carousel-controls">
        <button type="button" class="Carousel-rotation" data-carousel-rotation data-label-start="Start slide rotation" data-label-stop="Stop slide rotation">
          <span class="Carousel-rotation-icon" aria-hidden="true"></span>
          <span class="sr-only" data-carousel-rotation-label>Stop slide rotation</span>
        </button>
        <div class="Carousel-dots">
          ${indexes.map( i => `<button type="button" class="Carousel-dot" aria-label="Slide ${i + 1}" ${i === 0 ? "aria-current=\"true\"" : ""} data-carousel-dot="${i}"></button>` ).join( "" )}
        </div>
      </div>
      <div class="Carousel-track" aria-live="off" tabindex="-1" data-carousel-track>
        ${indexes.map( i => slideHtml( i, count ) ).join( "" )}
      </div>
    </div>
  `;
}

export const carousel = ( page: Page ) => page.locator( "[data-carousel-root]" );
export const dots = ( page: Page ) => carousel( page ).locator( "[data-carousel-dot]" );
export const slides = ( page: Page ) => carousel( page ).locator( "[data-carousel-slide]" );
export const rotation = ( page: Page ) => carousel( page ).locator( "[data-carousel-rotation]" );
export const track = ( page: Page ) => carousel( page ).locator( "[data-carousel-track]" );

export async function expectActiveSlide( page: Page, index: number ): Promise<void> {
  await expect( dots( page ).nth( index ) ).toHaveAttribute( "aria-current", "true" );
  await expect( slides( page ).nth( index ) ).not.toHaveAttribute( "inert", "" );
}

async function expectCarouselStarted( page: Page ): Promise<void> {
  await expect( carousel( page ) ).toHaveAttribute( "data-state", /rotating|stopped/ );
}

// Fingerprinted paths come from the manifest the e2e webServer's assets:precompile writes
function compiledAsset( logicalPath: string ): string {
  const manifestFile = fs.readdirSync( PUBLIC_ASSETS ).find( file => file.startsWith( ".sprockets-manifest" ) );
  const manifest = JSON.parse( fs.readFileSync( path.join( PUBLIC_ASSETS, manifestFile || "" ), "utf8" ) );
  return path.join( PUBLIC_ASSETS, manifest.assets[logicalPath] );
}

export async function mountCarousel( page: Page ): Promise<void> {
  await page.clock.install( );
  await page.setContent( `
    <div id="wrapper" class="bootstrap">
      <button id="before">Before</button>${carouselHtml( 3 )}<button id="after">After</button>
    </div>
  ` );
  await page.addStyleTag( { path: compiledAsset( "bootstrap_bundle.css" ) } );
  await page.addStyleTag( { path: compiledAsset( "projects/index_responsive.css" ) } );
  await page.addScriptTag( { path: compiledAsset( "webpack/runtime-webpack.js" ) } );
  await page.addScriptTag( { path: compiledAsset( "webpack/carousel-webpack.js" ) } );
  await expectCarouselStarted( page );
}
