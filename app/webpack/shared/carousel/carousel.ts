export interface CarouselOptions {
  autoplayMs?: number;
}

export function initCarousel( root: HTMLElement, { autoplayMs }: CarouselOptions = {} ): void {
  const track = root.querySelector<HTMLElement>( "[data-carousel-track]" );
  const slides = Array.from( root.querySelectorAll<HTMLElement>( "[data-carousel-slide]" ) );
  if ( !track || slides.length < 2 ) { return; }

  const dots = Array.from( root.querySelectorAll<HTMLElement>( "[data-carousel-dot]" ) );
  const rotation = root.querySelector<HTMLElement>( "[data-carousel-rotation]" );
  const rotationLabel = root.querySelector( "[data-carousel-rotation-label]" );
  const reducedMotion = window.matchMedia( "(prefers-reduced-motion: reduce)" ).matches;
  const visible = slides.map( ( _, i ) => i === 0 );
  const state = {
    active: 0,
    stopped: reducedMotion || !autoplayMs,
    hovered: false,
    timer: 0
  };

  function render( ) {
    slides.forEach( ( slide, i ) => slide.toggleAttribute( "inert", !visible[i] ) );
    dots.forEach( ( dot, i ) => dot.setAttribute( "aria-current", String( i === state.active ) ) );
  }

  function goTo( index: number ) {
    track?.scrollTo( {
      left: slides[index].offsetLeft,
      behavior: reducedMotion ? "auto" : "smooth"
    } );
  }

  function sync( ) {
    const rotating = !state.stopped && !state.hovered;
    window.clearInterval( state.timer );
    state.timer = rotating
      ? window.setInterval( ( ) => goTo( ( state.active + 1 ) % slides.length ), autoplayMs )
      : 0;
    track?.setAttribute( "aria-live", rotating ? "off" : "polite" );
    root.dataset.state = state.stopped ? "stopped" : "rotating";
    if ( rotation && rotationLabel ) {
      rotationLabel.textContent = rotation.dataset[state.stopped ? "labelStart" : "labelStop"] || "";
    }
  }

  function stop( ) {
    state.stopped = true;
    sync( );
  }

  const observer = new IntersectionObserver( entries => {
    entries.forEach( entry => {
      visible[slides.indexOf( entry.target as HTMLElement )] = entry.isIntersecting
        && entry.intersectionRatio >= 0.5;
    } );
    state.active = visible.includes( true ) ? visible.indexOf( true ) : state.active;
    render( );
  }, { root: track, threshold: 0.5 } );
  slides.forEach( slide => observer.observe( slide ) );

  rotation?.addEventListener( "click", ( ) => {
    state.stopped = !state.stopped;
    sync( );
  } );
  dots.forEach( ( dot, i ) => dot.addEventListener( "click", ( ) => {
    stop( );
    goTo( i );
  } ) );
  root.addEventListener( "focusin", e => {
    if ( ( e.target as HTMLElement ).matches( ":focus-visible" ) ) { stop( ); }
  } );
  root.addEventListener( "mouseenter", ( ) => {
    state.hovered = true;
    sync( );
  } );
  root.addEventListener( "mouseleave", ( ) => {
    state.hovered = false;
    sync( );
  } );
  track.addEventListener( "touchstart", stop, { passive: true } );
  track.addEventListener( "wheel", e => {
    if ( Math.abs( e.deltaX ) > Math.abs( e.deltaY ) ) { stop( ); }
  }, { passive: true } );

  render( );
  sync( );
}
