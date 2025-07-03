$( ( ) => {
  $( "td.word" ).on( "mouseover", function ( ) {
    $( this ).text( $( this ).attr( "original" ) );
  } ).on( "mouseout", function ( ) {
    $( this ).text( $( this ).attr( "obfuscated" ) );
  } );
} );
