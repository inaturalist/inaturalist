import { initCarousel } from "./carousel";

type IOCallback = ( entries: Partial<IntersectionObserverEntry>[] ) => void;

let ioCallback: IOCallback;
let reducedMotion = false;
const scrollTo = jest.fn( );

function fixture( count: number ): HTMLElement {
  const dots = Array.from( { length: count }, ( _, i ) => (
    `<button type="button" class="dot" aria-label="Slide ${i + 1}" data-carousel-dot="${i}"></button>`
  ) ).join( "" );
  const slides = Array.from( { length: count }, ( _, i ) => (
    `<div role="group" data-carousel-slide><a href="/projects/${i}">Project ${i}</a></div>`
  ) ).join( "" );
  document.body.innerHTML = `
    <section data-carousel-root>
      <div>
        <button type="button" data-carousel-rotation
          data-label-start="start_slide_rotation" data-label-stop="stop_slide_rotation">
          <span data-carousel-rotation-label>stop_slide_rotation</span>
        </button>
        ${dots}
      </div>
      <div data-carousel-track aria-live="off">${slides}</div>
    </section>
  `;
  document.querySelectorAll<HTMLElement>( "[data-carousel-slide]" ).forEach( ( slide, i ) => {
    Object.defineProperty( slide, "offsetLeft", { value: i * 100 } );
  } );
  return document.querySelector( "[data-carousel-root]" ) as HTMLElement;
}

const root = ( ) => document.querySelector( "[data-carousel-root]" ) as HTMLElement;
const track = ( ) => root( ).querySelector( "[data-carousel-track]" ) as HTMLElement;
const slides = ( ) => Array.from( root( ).querySelectorAll<HTMLElement>( "[data-carousel-slide]" ) );
const dots = ( ) => Array.from( root( ).querySelectorAll<HTMLElement>( "[data-carousel-dot]" ) );
const rotation = ( ) => root( ).querySelector( "[data-carousel-rotation]" ) as HTMLButtonElement;
const label = ( ) => rotation( ).textContent?.trim( );
const inert = ( ) => slides( ).map( slide => slide.hasAttribute( "inert" ) );
const current = ( ) => dots( ).map( dot => dot.getAttribute( "aria-current" ) === "true" );

function show( index: number ) {
  ioCallback( slides( ).map( ( target, i ) => ( {
    target,
    isIntersecting: i === index,
    intersectionRatio: i === index ? 1 : 0
  } ) ) );
}

function init( count = 3 ) {
  initCarousel( fixture( count ), { autoplayMs: 5000 } );
}

beforeEach( ( ) => {
  jest.useFakeTimers( );
  reducedMotion = false;
  scrollTo.mockClear( );
  HTMLElement.prototype.scrollTo = scrollTo;
  ( global as unknown as Record<string, unknown> ).IntersectionObserver = function IO(
    callback: IOCallback
  ) {
    ioCallback = callback;
    return { observe: ( ) => undefined, disconnect: ( ) => undefined };
  };
  window.matchMedia = ( query: string ) => ( {
    matches: reducedMotion && query.includes( "prefers-reduced-motion" )
  } ) as MediaQueryList;
} );

afterEach( ( ) => {
  jest.useRealTimers( );
} );

describe( "initCarousel", ( ) => {
  it( "shows only the first slide on init", ( ) => {
    init( );
    expect( inert( ) ).toEqual( [false, true, true] );
    expect( current( ) ).toEqual( [true, false, false] );
  } );

  it( "advances to the next slide after the autoplay delay", ( ) => {
    init( );
    jest.advanceTimersByTime( 4999 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    jest.advanceTimersByTime( 1 );
    expect( scrollTo ).toHaveBeenCalledWith( { left: 100, behavior: "smooth" } );
  } );

  it( "wraps from the last slide to the first", ( ) => {
    init( );
    show( 2 );
    jest.advanceTimersByTime( 5000 );
    expect( scrollTo ).toHaveBeenLastCalledWith( { left: 0, behavior: "smooth" } );
  } );

  it( "follows the visible slide when it changes, e.g. from a swipe", ( ) => {
    init( );
    show( 1 );
    expect( inert( ) ).toEqual( [true, false, true] );
    expect( current( ) ).toEqual( [false, true, false] );
  } );

  it( "keeps the live region off while rotating", ( ) => {
    init( );
    expect( track( ).getAttribute( "aria-live" ) ).toBe( "off" );
    expect( label( ) ).toBe( "stop_slide_rotation" );
    expect( root( ).dataset.state ).toBe( "rotating" );
  } );

  it( "stops and restarts rotation from the rotation button", ( ) => {
    init( );
    const button = rotation( );
    button.click( );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    expect( track( ).getAttribute( "aria-live" ) ).toBe( "polite" );
    expect( label( ) ).toBe( "start_slide_rotation" );
    expect( root( ).dataset.state ).toBe( "stopped" );
    expect( rotation( ) ).toBe( button );

    button.click( );
    jest.advanceTimersByTime( 4999 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    jest.advanceTimersByTime( 1 );
    expect( scrollTo ).toHaveBeenCalledTimes( 1 );
    expect( label( ) ).toBe( "stop_slide_rotation" );
  } );

  it( "pauses while hovered without changing the button label", ( ) => {
    init( );
    root( ).dispatchEvent( new MouseEvent( "mouseenter" ) );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    expect( label( ) ).toBe( "stop_slide_rotation" );
    expect( track( ).getAttribute( "aria-live" ) ).toBe( "polite" );

    root( ).dispatchEvent( new MouseEvent( "mouseleave" ) );
    jest.advanceTimersByTime( 5000 );
    expect( scrollTo ).toHaveBeenCalledTimes( 1 );
  } );

  it( "does not resume on mouseleave after an explicit stop", ( ) => {
    init( );
    root( ).dispatchEvent( new MouseEvent( "mouseenter" ) );
    rotation( ).click( );
    root( ).dispatchEvent( new MouseEvent( "mouseleave" ) );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
  } );

  it( "stops when keyboard focus enters and only the button restarts it", ( ) => {
    init( );
    slides( )[0].querySelector( "a" )?.focus( );
    ( document.activeElement as HTMLElement ).blur( );
    root( ).dispatchEvent( new MouseEvent( "mouseleave" ) );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    expect( label( ) ).toBe( "start_slide_rotation" );
  } );

  it( "scrolls to a slide when its dot is clicked and stops rotating", ( ) => {
    init( );
    dots( )[2].click( );
    expect( scrollTo ).toHaveBeenCalledWith( { left: 200, behavior: "smooth" } );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).toHaveBeenCalledTimes( 1 );
    expect( label( ) ).toBe( "start_slide_rotation" );
  } );

  it( "stops rotating when the user touches the track", ( ) => {
    init( );
    track( ).dispatchEvent( new Event( "touchstart" ) );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
  } );

  it( "stops rotating on horizontal but not vertical wheel scrolling", ( ) => {
    init( );
    track( ).dispatchEvent( new WheelEvent( "wheel", { deltaX: 0, deltaY: 40 } ) );
    expect( label( ) ).toBe( "stop_slide_rotation" );
    track( ).dispatchEvent( new WheelEvent( "wheel", { deltaX: 40, deltaY: 5 } ) );
    expect( label( ) ).toBe( "start_slide_rotation" );
  } );

  it( "does not autoplay or animate when reduced motion is preferred", ( ) => {
    reducedMotion = true;
    init( );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    expect( label( ) ).toBe( "start_slide_rotation" );
    expect( track( ).getAttribute( "aria-live" ) ).toBe( "polite" );
    dots( )[1].click( );
    expect( scrollTo ).toHaveBeenCalledWith( { left: 100, behavior: "auto" } );
  } );

  it( "does nothing with a single slide", ( ) => {
    init( 1 );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    expect( inert( ) ).toEqual( [false] );
  } );

  it( "does not rotate without an autoplay delay", ( ) => {
    initCarousel( fixture( 3 ) );
    jest.advanceTimersByTime( 10000 );
    expect( scrollTo ).not.toHaveBeenCalled( );
    expect( track( ).getAttribute( "aria-live" ) ).toBe( "polite" );
  } );
} );
