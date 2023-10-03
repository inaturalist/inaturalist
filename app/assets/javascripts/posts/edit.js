/* global _ */

$( function ( ) {
  $( "#post_body" ).textcompleteUsers( );

  // used to keep track of when the delete button was clicked. Clicking `delete`
  // will cause the page location to be changed without submitting the form, but
  // since this is a user-initiated action that already has a confirmation
  // prompt, do not allow onbeforeunload to issue a second warning
  var DELETE_CLICKED = false;
  $( ".post_form" ).submit( function ( ) {
    $( ".post_form" ).data( { submitted: true } );
    DELETE_CLICKED = false;
  } );

  $( "#delete_post_button" ).on( "click", function ( ) {
    DELETE_CLICKED = true;
  } );

  // use `window.onbeforeunload` to trigger a browser warning when leaving the page
  // and there is any text at all in either the title or body of the post
  window.onbeforeunload = function ( ) {
    if ( $( ".post_form" ).data( "submitted" ) || DELETE_CLICKED ) {
      return null;
    }
    return ( !_.isEmpty( $( "#post_title" ).val( ) )
      || !_.isEmpty( $( "#post_body" ).val( ) ) ) ? true : null;
  };
} );
