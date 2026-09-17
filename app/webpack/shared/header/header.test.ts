import { formatHeaderCount, readHeaderCounts } from "./header";

describe( "formatHeaderCount", ( ) => {
  it( "renders counts up to the cap verbatim", ( ) => {
    expect( formatHeaderCount( 0 ) ).toBe( "0" );
    expect( formatHeaderCount( 999 ) ).toBe( "999" );
  } );

  it( "caps anything larger", ( ) => {
    expect( formatHeaderCount( 1000 ) ).toBe( "999+" );
    expect( formatHeaderCount( 99999 ) ).toBe( "999+" );
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
