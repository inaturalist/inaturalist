import { fitHeader, initHeaderCounts } from "./header";

describe( "fitHeader", ( ) => {
  interface Widths { scrollWidth: number; clientWidth: number }

  const renderHeader = ( { scrollWidth, clientWidth }: Widths ) => {
    document.body.innerHTML = "<div id=\"header\"></div>";
    const header = document.getElementById( "header" ) as HTMLElement;
    // jsdom lays nothing out, so both widths are 0 without this
    Object.defineProperty( header, "scrollWidth", { value: scrollWidth } );
    Object.defineProperty( header, "clientWidth", { value: clientWidth } );
    return header;
  };

  it( "leaves a header that fits alone", ( ) => {
    const header = renderHeader( { scrollWidth: 375, clientWidth: 375 } );

    fitHeader( );

    expect( header.classList.contains( "crowded" ) ).toBe( false );
  } );

  it( "marks a header whose contents overflow", ( ) => {
    const header = renderHeader( { scrollWidth: 383, clientWidth: 375 } );

    fitHeader( );

    expect( header.classList.contains( "crowded" ) ).toBe( true );
  } );

  it( "clears the mark once the header fits again", ( ) => {
    const header = renderHeader( { scrollWidth: 375, clientWidth: 375 } );
    header.classList.add( "crowded" );

    fitHeader( );

    expect( header.classList.contains( "crowded" ) ).toBe( false );
  } );

  it( "does nothing on a page with no header", ( ) => {
    document.body.innerHTML = "";

    expect( ( ) => fitHeader( ) ).not.toThrow( );
  } );
} );

describe( "initHeaderCounts", ( ) => {
  let countHtml: jest.Mock;

  beforeEach( ( ) => {
    jest.useFakeTimers( );
    countHtml = jest.fn( );
    // Minimal jQuery stand-in: setHeaderCount only needs class toggles and .html
    const chain = {
      addClass: jest.fn( ),
      removeClass: jest.fn( ),
      switchClass: jest.fn( ),
      html: countHtml,
      on: jest.fn( )
    };
    ( global as unknown as Record<string, unknown> ).$ = jest.fn( ( ) => chain );
  } );

  afterEach( ( ) => {
    jest.useRealTimers( );
  } );

  it( "applies the counts stamped on #header", ( ) => {
    document.body.innerHTML = "<div id=\"header\" data-updates-count=\"5\" data-messages-count=\"3\"></div>";

    initHeaderCounts( );

    expect( countHtml ).toHaveBeenCalledWith( "5" );
    expect( countHtml ).toHaveBeenCalledWith( "3" );
  } );

  it( "does nothing when the counts are absent", ( ) => {
    document.body.innerHTML = "<div id=\"header\"></div>";

    initHeaderCounts( );

    expect( countHtml ).not.toHaveBeenCalled( );
  } );
} );
