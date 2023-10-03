$( function ( ) {
  $( "a.hidden-image" ).on( "click", function ( e ) {
    e.preventDefault( );
    // open a new window now in the context of the user action so it doesn't get popup-blocked
    var resourceWindow = window.open( );
    $.ajax( "/moderator_actions/" + $( this ).data( "moderatorActionId" ) + "/resource_url", {
      method: "GET",
      data: {
        size: $( this ).data( "size" )
      },
      dataType: "json",
      authenticity_token: $( "meta[name=csrf-param]" ).attr( "content" ),
      success: function ( response ) {
        if ( response && response.resource_url ) {
          // update the location of the already opened window
          resourceWindow.location = response.resource_url;
          resourceWindow.focus( );
        }
      }
    } );
  } );
} );
