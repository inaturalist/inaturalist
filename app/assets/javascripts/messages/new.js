/* global _ */

$( document ).ready( function ( ) {
  if ( $( "#new_message .user_name" ).length > 0 ) {
    $( "#new_message .user_name" ).userAutocomplete( {
      resetOnChange: false,
      idEl: $( "#new_message .user_name" ),
      afterSelect: function ( result ) {
        $( "#new_message .user-field img" ).attr( { src: result.item.icon } );
        $( "#message_to_user_id" ).val( result.item.user_id );
      },
      afterUnselect: function ( ) {
        $( "#new_message .user-field img" ).attr( { src: $( "#new_message .user-field img" ).data( "original-src" ) } );
        $( "#message_to_user_id" ).val( "" );
      }
    } );
  }

  $( "#new_message" ).submit( function ( ) {
    $( "#new_message" ).data( { submitted: true } );
  } );

  // use `window.onbeforeunload` to trigger a browser warning when leaving the page
  // and there is any text at all in either the subject or body of the new message
  window.onbeforeunload = function ( ) {
    if ( $( "#new_message" ).data( "submitted" ) ) {
      return null;
    }
    return ( !_.isEmpty( $( "#message_subject" ).val( ) )
      || !_.isEmpty( $( "#message_body" ).val( ) ) ) ? true : null;
  };
} );
