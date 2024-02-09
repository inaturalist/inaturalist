/* global _ */

$( document ).ready( function ( ) {
  $( "#new_message" ).submit( function ( ) {
    $( "#new_message" ).data( { submitted: true } );
  } );

  // use `window.onbeforeunload` to trigger a browser warning when leaving the page
  // and there is any text at all in either the subject or body of the new message
  window.onbeforeunload = function ( ) {
    if ( $( "#new_message" ).data( "submitted" ) ) {
      return null;
    }
    return !_.isEmpty( $( "#message_body" ).val( ) ) ? true : null;
  };
} );
