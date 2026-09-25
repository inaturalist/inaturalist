import { initCarousel } from "./carousel";

function start( ): void {
  document.querySelectorAll<HTMLElement>( "[data-carousel-root]" ).forEach( root => {
    initCarousel( root, { autoplayMs: Number( root.dataset.carouselAutoplay ) || undefined } );
  } );
}

if ( document.readyState === "loading" ) {
  document.addEventListener( "DOMContentLoaded", start );
} else {
  start( );
}
