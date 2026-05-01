function initAnnouncementDismiss( announcementId ) {
  var announcementRoot = document.getElementById( announcementId );
  if ( !announcementRoot ) return;
  $( announcementRoot ).find( "form" ).on( "submit", function( e ) {
    e.preventDefault( );
    $( announcementRoot ).fadeOut( );
    $.ajax( {
      type: "PUT",
      url: $( this ).attr( "action" )
    } );
  } );
}
