var recaptchaCallback = function ( ) {
  $( ".sign-up [type='submit']" ).prop( "disabled", false );
};
$( document ).ready( function ( ) {
  if ( $( ".time_zone_select" ).length > 0 ) {
    var userZone = moment.tz.guess( );
    if ( userZone ) {
      var option = $( ".time_zone_select option[data-tz-name='" + userZone + "']" );
      $( ".time_zone_select" ).val( option.attr( "value" ) );
    }
    $( ".time_zone_select" ).selectLocalTimeZone( );
    $( "html" ).click( function ( ) {
      $( '[data-toggle="popover"]' ).popover( "hide" );
    } );
  }
  $( '[data-toggle="popover"]' ).popover( {
    html: true,
    trigger: "manual"
  } ).click( function ( e ) {
    $( this ).popover( "toggle" );
    e.stopPropagation( );
  } );
  $( "#license-all" ).click( function ( ) {
    $( "#license-fields input[type=checkbox]" ).click( );
  } );
} );
