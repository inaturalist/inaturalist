$( function () {
  var durationSelect = document.getElementById( "suspension_duration" );
  var customField = document.querySelector( ".custom-suspended-until-field" );
  var hiddenUtc = document.getElementById( "suspended_until_utc" );
  var localPicker = document.getElementById( "suspended_until_local" );

  function toISOString( date ) {
    return date.toISOString().replace( /\.\d{3}Z$/, "Z" );
  }

  function computeUtcFromDuration( duration ) {
    var now = new Date();
    switch ( duration ) {
      case "1_day":
        return toISOString( new Date( now.getTime() + 1 * 24 * 60 * 60 * 1000 ) );
      case "3_days":
        return toISOString( new Date( now.getTime() + 3 * 24 * 60 * 60 * 1000 ) );
      case "1_week":
        return toISOString( new Date( now.getTime() + 7 * 24 * 60 * 60 * 1000 ) );
      case "1_month":
        var d = new Date( now );
        d.setMonth( d.getMonth() + 1 );
        return toISOString( d );
      case "2_months":
        var d = new Date( now );
        d.setMonth( d.getMonth() + 2 );
        return toISOString( d );
      case "indefinite":
        return "";
      case "custom":
        return "";
      default:
        return "";
    }
  }

  function updateSuspendedUntil() {
    var duration = durationSelect.value;
    if ( duration === "custom" ) {
      customField.style.display = "";
      if ( localPicker.value ) {
        var localDate = new Date( localPicker.value );
        hiddenUtc.value = toISOString( localDate );
      } else {
        hiddenUtc.value = "";
      }
    } else {
      customField.style.display = "none";
      localPicker.value = "";
      hiddenUtc.value = computeUtcFromDuration( duration );
    }
  }

  durationSelect.addEventListener( "change", updateSuspendedUntil );
  localPicker.addEventListener( "change", function () {
    if ( localPicker.value ) {
      var localDate = new Date( localPicker.value );
      hiddenUtc.value = toISOString( localDate );
    } else {
      hiddenUtc.value = "";
    }
  } );

  // Set initial value for the default selection (1 day)
  updateSuspendedUntil();
}() );
