var recaptchaCallback = function ( ) {
  $( ".sign-up [type='submit']" ).prop( "disabled", false );
};
$( document ).ready( function ( ) {
  let browserId = localStorage.getItem( "browserUID" );
  if ( !browserId ) {
    if ( typeof crypto !== "undefined" && typeof crypto.randomUUID === "function" ) {
      browserId = crypto.randomUUID();
    } else {
      browserId = Math.random().toString( 36 ).substr( 2, 32 );
    }
    localStorage.setItem( "browserUID", browserId );
  }
  const browserIdField = document.getElementById( "browser_id" );
  if ( browserIdField ) {
    browserIdField.value = browserId;
  }
  detectIncognito().then(( result ) => {
    const incognitoField = document.getElementById( "incognito_mode" );
    if ( incognitoField ) {
      incognitoField.value = result.isPrivate ? "true" : "false";
    }
  }).catch(( error ) => {
      console.error( "Error detecting incognito mode:", error );
  });
  if ( $( ".time_zone_select" ).length > 0 ) {
    var userZone = moment.tz.guess( );
    if ( userZone ) {
      var option = $( ".time_zone_select option[data-tz-name='" + userZone + "']" );
      $( ".time_zone_select" ).val( option.attr( "value" ) );
    }
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
  $( ".date-picker" ).datepicker( {
    yearRange: "c-100:" + ( new Date( ) ).getFullYear( ),
    maxDate: "+0d",
    constrainInput: false,
    firstDay: 0,
    changeFirstDay: false,
    changeMonth: true,
    changeYear: true,
    dateFormat: "yy-mm-dd",
    showTimezone: false,
    closeText: I18n.t( "date_picker.closeText" ),
    currentText: I18n.t( "date_picker.currentText" ),
    prevText: I18n.t( "date_picker.prevText" ),
    nextText: I18n.t( "date_picker.nextText" ),
    montNames: _.compact( _.values( I18n.t( "date.month_names" ) ) ),
    monthNamesShort: _.compact( _.values( I18n.t( "date.abbr_month_names" ) ) ),
    dayNames: _.compact( _.values( I18n.t( "date.day_names" ) ) ),
    dayNamesShort: _.compact( _.values( I18n.t( "date.abbr_day_names" ) ) ),
    dayNamesMin: _.compact( _.values( I18n.t( "date.day_names_min" ) ) )
  } );
} );
