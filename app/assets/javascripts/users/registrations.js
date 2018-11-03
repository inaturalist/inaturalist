var RecaptchaCallback = function( response ) {
  $( "#signup_form .button[type='submit']" ).prop( "disabled", false );
};
$(document).ready(function() {
  var userZone = moment.tz.guess( );
  if ( userZone ) {
    var option = $( ".time_zone_select option[data-tz-name='"+userZone+"']" );
    $( ".time_zone_select" ).val( option.attr( "value" ) );
  }
  $( ".time_zone_select" ).selectLocalTimeZone( );
  $( "html" ).click( function( e ) {
    $( '[data-toggle="popover"]' ).popover( "hide" );
  } );
  $( '[data-toggle="popover"]' ).popover( {
    html: true,
    trigger: "manual"
  } ).click( function( e ) { 
    $(this).popover( "toggle" );
    e.stopPropagation( );
  } );
  $( "#license-all" ).click( function( ) {
    $( "#license-fields input[type=checkbox]" ).click( );
  } );
} );
