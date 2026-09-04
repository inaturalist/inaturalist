import { fitHeader, readHeaderCounts } from "./header";

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

describe( "readHeaderCounts", ( ) => {
  it( "reads the counts stamped on #header", ( ) => {
    document.body.innerHTML = "<div id=\"header\" data-updates-count=\"5\" data-messages-count=\"3\"></div>";

    expect( readHeaderCounts( ) ).toEqual( { updates: 5, messages: 3 } );
  } );

  it( "returns null when the counts are absent", ( ) => {
    document.body.innerHTML = "<div id=\"header\"></div>";

    expect( readHeaderCounts( ) ).toBeNull( );
  } );
} );
