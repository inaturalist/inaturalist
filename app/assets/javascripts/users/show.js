/* global I18n */

var setupMuteAction = function ( link ) {
  link.off( "click" );
  if ( link.data( "existingMuteId" ) ) {
    link.on( "click", function ( e ) {
      e.preventDefault( );
      $.ajax( "/user_mutes/" + link.data( "existingMuteId" ), {
        method: "DELETE",
        dataType: "json",
        authenticity_token: $( "meta[name=csrf-param]" ).attr( "content" ),
        success: function ( ) {
          link.data( "existingMuteId", null );
          link.html( "<i class=\"fa fa-microphone-slash\" /> " + I18n.t( "mute" ) );
          setupMuteAction( $( link ) );
        }
      } );
    } );
    return;
  }
  link.confirmModal( {
    titleText: I18n.t( "are_you_sure?" ),
    confirmText: I18n.t( "mute" ),
    text: function ( ) {
      return I18n.t( "muting_description" );
    },
    onConfirm: function ( ) {
      $.ajax( "/user_mutes", {
        method: "POST",
        dataType: "json",
        authenticity_token: $( "meta[name=csrf-param]" ).attr( "content" ),
        data: {
          user_mute: {
            muted_user_id: link.data( "mutedUserId" )
          }
        },
        success: function ( data ) {
          link.data( "existingMuteId", data.id );
          link.html( "<i class=\"fa fa-microphone\" /> " + I18n.t( "unmute" ) );
          setupMuteAction( link );
        }
      } );
    }
  } );
};

$( function ( ) {
  $( "#nodescription .cancellink" ).click( function ( e ) {
    $( "#nodescription" ).removeClass( "editing" );
    $( "#nodescription" ).find( ".more" ).show( );
    $( "#nodescription" ).find( "form" ).hide( );
    e.stopPropagation( );
    return false;
  } );

  $( "#nodescription" ).click( function ( ) {
    if ( $( this ).hasClass( "editing" ) ) { return true; }
    $( this ).addClass( "editing" );
    $( this ).find( ".more" ).hide( );
    $( this ).find( "form" ).show( );
    return false;
  } );

  $( "a.muting" ).each( function ( ) {
    setupMuteAction( $( this ) );
  } );
} );
