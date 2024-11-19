$( function ( ) {
  $( ".btn[data-method='delete']" ).click( function ( e ) {
    var confirmText = $( e.target ).data( "confirm" );
    e.preventDefault( );
    e.stopPropagation( );
    // eslint-disable-next-line no-alert
    if ( window.confirm( confirmText ) === true ) {
      $( "input[name=\"_method\"]" ).val( "delete" );
      $( "form.edit_conservation_status" ).submit( );
    }
  } );
} );
