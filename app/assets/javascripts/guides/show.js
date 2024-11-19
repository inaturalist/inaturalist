$( ".tile .img" ).imagesLoaded( function ( ) {
  $( "img", this ).not( ".iconic" ).centerInContainer( );
} );
$( ".clearbtn" ).click( function ( ) {
  $( this ).siblings( ":input" ).val( null );
} );
$( ".taxonmap" ).waypoint( function ( ) {
  if ( $( this ).data( "taxonMap" ) ) {
    return;
  }
  $( this ).taxonMap( );
}, {
  triggerOnce: true,
  offset: "100%"
} );
$( "#printbtn" ).click( function ( ) {
  var layout = $( "#print_dialog input[name*=layout]:checked" ).val( );
  var printUrl = window.location.toString( );
  if ( printUrl.indexOf( "?" ) >= 0 ) {
    printUrl += "&print=t";
  } else {
    printUrl += "?print=t";
  }
  printUrl += "&layout=" + layout;
  window.open( printUrl, "_blank", "noopener,noreferrer" );
  return false;
} );
