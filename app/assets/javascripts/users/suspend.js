$( function () {
  var durationSelect = document.getElementById( "suspension_duration" );
  var customField = document.querySelector( ".custom-suspended-until-field" );
  var hiddenUtc = document.getElementById( "suspended_until_utc" );
  var localPicker = document.getElementById( "suspended_until_local" );
  var reasonSelect = document.getElementById( "suspension_reason" );
  var customReasonField = document.querySelector( ".custom-reason-field" );
  var reasonTextArea = document.getElementById( "moderator_action_reason" );
  var hiddenReason = document.getElementById( "hidden_reason" );

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
    if ( !durationSelect ) return;

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

  if ( localPicker ) {
    var minDate = new Date();
    var localISO = new Date( minDate.getTime() - minDate.getTimezoneOffset() * 60000 );
    localPicker.min = localISO.toISOString().slice( 0, 16 );

    // Pre-populate local picker from existing UTC value (e.g. when editing)
    var { initialUtc } = localPicker.dataset;
    if ( initialUtc ) {
      var initialDate = new Date( initialUtc );
      var offset = initialDate.getTimezoneOffset() * 60000;
      var initialLocal = new Date( initialDate.getTime() - offset );
      localPicker.value = initialLocal.toISOString().slice( 0, 16 );
    }

    localPicker.addEventListener( "change", function () {
      if ( localPicker.value ) {
        var localDate = new Date( localPicker.value );
        hiddenUtc.value = toISOString( localDate );
      } else {
        hiddenUtc.value = "";
      }
    } );
  }

  if ( durationSelect ) {
    durationSelect.addEventListener( "change", updateSuspendedUntil );
  }

  var updateSuspensionReason = function () {
    var selectedReason = reasonSelect.value;
    if ( selectedReason === "custom" ) {
      customReasonField.style.display = "";
      hiddenReason.disabled = true;
      reasonTextArea.disabled = false;
      reasonTextArea.required = true;
    } else {
      customReasonField.style.display = "none";
      reasonTextArea.disabled = true;
      reasonTextArea.required = false;
      hiddenReason.disabled = false;
      hiddenReason.value = selectedReason;

      // Update duration to the default for this reason
      /* eslint-disable no-undef */
      if ( durationSelect
        && typeof SUSPENSION_REASON_DURATIONS !== "undefined"
      ) {
        var defaultDuration = SUSPENSION_REASON_DURATIONS[selectedReason];
        /* eslint-enable no-undef */
        if ( defaultDuration ) {
          durationSelect.value = defaultDuration;
          updateSuspendedUntil();
        }
      }
    }
  };

  if ( reasonSelect ) {
    reasonSelect.addEventListener( "change", updateSuspensionReason );
    updateSuspensionReason();
  }

  updateSuspendedUntil();
}() );
