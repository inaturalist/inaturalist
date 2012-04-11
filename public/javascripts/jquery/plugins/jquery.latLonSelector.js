(function($){
  $.fn.latLonSelector = function(options) {
    var options = $.extend({}, $.fn.latLonSelector.defaults, options);
    $.fn.latLonSelector._options = options;
    
    // Insert a SINGLE map div at the bottom of the page    
    var wrapper = $('<div id="latLonSelector"></div>');
    if (typeof(options.mapDiv) == 'undefined') {
      var mapDiv = $('<div></div>').css(options.mapCSS);
      $(wrapper).append(mapDiv);
    } else {
      var mapDiv = options.mapDiv;
    }
    $(wrapper).css(options.wrapperCSS);
    $(mapDiv).addClass('latLonSelectorMap');
    $('body').append(wrapper);
    
    // Insert controls
    var controls = $('<div id="latLonSelectorControls"></div>');
    $(controls).css({
      'text-align': 'right'
    });
    var button = $('<a id="latLonSelectorSearchButton" href="#">Search</a>');
    $(button).css(options.buttonCSS);
    $(button).click(function(e) {
      var input = getCurrentInput();
      $.fn.latLonSelector.lookup($(input).val());
      return false;
    });
    var clear = $('<a href="#">Clear</a>').css({'margin-right': '1em'});
    $(clear).click(function(e) {
      var input = getCurrentInput();
      $.fn.latLonSelector.updateFormLatLon('', '');
      $(input).val('');
      var scaleField = findFormField(input, 'map_scale');
      if (typeof scaleField != 'undefined') {
        $(scaleField).val('');
      };
      setExact(false);
      getMarker().setMap(null);
      $.fn.latLonSelector.setAccuracy(null)
      $.fn.latLonSelector.updateFormAccuracy(null)
      return false;
    });
    var close = $('<a href="#">'+options.closeText+'</a>').css(options.closeCSS);
    $(close).click(function(e) {
      $.fn.latLonSelector.hideMap();
      return false;
    });
    $(controls).append(button, clear, close);
    $(wrapper).prepend(controls);
    
    // Setup the map
    if (typeof options.map != 'undefined') {
      var map = $.fn.latLonSelector._map = options.map;
    } else {
      var map = $.fn.latLonSelector._map = new google.maps.Map($(mapDiv).get(0), {
        zoom: 1,
        center: new google.maps.LatLng(0,0),
        mapTypeId: google.maps.MapTypeId.ROADMAP,
        streetViewControl: false
      })
    }
    
    // Clicks outside the selector should close it
    $(document.body).mousedown(function(e) {
      var $target = $(e.target);
      if ($target.parents('#latLonSelector').length == 0 &&
          !$target.hasClass('latLonSelectorInput') &&
          !$target.hasClass('latLonSelectorButton')) {
        $.fn.latLonSelector.hideMap();
      }
    });
    
    // Listen for clicks on the map
    google.maps.event.addListener(map, 'click', handleMapClick);
    
    // Update scale field on zoomend
    google.maps.event.addListener(map, 'zoom_changed', function() {
      $.fn.latLonSelector._currentInput._lastScale = map.getZoom()
      $.fn.latLonSelector.updateFormScale(map.getZoom())
    })
    
    // Set the default markers
    if (typeof options.marker != 'undefined') {
      $.fn.latLonSelector._exactMarker = options.marker;
    } else {
      $.fn.latLonSelector._exactMarker = new google.maps.Marker(new google.maps.LatLng(0,0))
      $.fn.latLonSelector._exactMarker.setDraggable(true)
    }
    $.fn.latLonSelector._exactMarker.setMap($.fn.latLonSelector._map)
    var marker = $.fn.latLonSelector._exactMarker
    
    // Bind dragend
    google.maps.event.clearListeners(marker, 'dragend');
    google.maps.event.addListener(marker, 'dragend', function(e) {
      $(findFormField($.fn.latLonSelector._currentInput, 'positioning_method')).val('manual')
      $(findFormField($.fn.latLonSelector._currentInput, 'positioning_device')).val('manual')
      
      $.fn.latLonSelector.updateFormLatLon(
        e.latLng.lat(), 
        e.latLng.lng()
      )
      
      if ($.fn.latLonSelector._circle) {
        $.fn.latLonSelector._circle.setCenter(this.getPosition())
        if (!$.fn.latLonSelector._circle.getEditable()) {
          $.fn.latLonSelector.setAccuracy(null)
          $.fn.latLonSelector.updateFormAccuracy(null)
        }
      }
    })
    
    google.maps.event.addListener(marker, 'click', function() {
      $.fn.latLonSelector.toggleEditAccuracy()
      return false
    })
    
    
    if (typeof options.approxMarker != 'undefined') {
      $.fn.latLonSelector._approxMarker = options.approxMarker;
    } else {
      $.fn.latLonSelector._approxMarker = new google.maps.Marker(new google.maps.LatLng(0,0))
      $.fn.latLonSelector._approxMarker.setDraggable(true)
    }
    $.fn.latLonSelector._approxMarker.setMap($.fn.latLonSelector._map)
    $.fn.latLonSelector._approxMarker.setVisible(false);
    
    
    // Insert the data controls
    var dataControls = $('<div id="latLonSelectorDataControls"></div>');
    $(dataControls).css({
      color: '#888',
      clear: 'left'
    });
    $(dataControls).append(
      $('<input id="latLonSelectorExactFlag" type="checkbox"/>').click(function(e) {
        setExact(this.checked);
        getMarker({exact: this.checked});
      }).hide(),
      $('<label for="latLonSelectorExactFlag">Exact location</label>').hide()
    );
    $(wrapper).append(dataControls);
    
    // Setup each input
    $(this).each(function() {
      setup(this, options);
    });
    
    // If embedded map, show the wrapper on the first input
    if (typeof(options.mapDiv) != 'undefined') {
      $.fn.latLonSelector.showMap($(this).get(0));
      $.fn.latLonSelector.hideMap($(this).get(0));
    };
  };
  
  function setup(input, options) {
    // Give it some class
    $(input).addClass('latLonSelectorInput');
    
    if (typeof options.buttonImgPath != 'undefined') {
      // Resize the input and add button
      $(input).width($(input).width() - 26);
      $(input).css({
        'margin-right': '10px',
        'vertical-align': 'middle'
      });
      var button = $('<img src="'+options.buttonImgPath+'">');
      $(button).addClass('latLonSelectorButton');
      button.css({'vertical-align': 'middle'});
      $(button).insertAfter(input);

      // Bind button to show the map
      $(button).click(function(e) {
        if ($('#latLonSelector:visible').length == 0) {
          $(input).get(0).focus();
        } else {
          $.fn.latLonSelector.hideMap(input);
        }
        return false;
      });
    };
    
    // Bind focus/blur to show the map
    $(input).focus(function(e) {
      if ($('#latLonSelector:visible').length == 0) {
        $.fn.latLonSelector.showMap(input);
      } else if ($.fn.latLonSelector._currentInput != input){
        $.fn.latLonSelector.showMap(input);
      }
      return false;
    })
    
    // Bind ENTER in input to search the map
    $(input).keypress(function(e) {
      if (e.which == 13) {
        // Catch exceptions to ensure false return and precent form submission
        try {
          $.fn.latLonSelector.lookup($(input).val());
        } catch (e) {
          logMessage(e);
        }
        return false;
      };
    })
    
    var accuracyField = findFormField(input, 'positional_accuracy')
    if (accuracyField) {
      $(accuracyField).change(function() {
        var acc = parseInt($(this).val())
        $.fn.latLonSelector.setAccuracy($(this).val())
        if (acc) {
          $.fn.latLonSelector.editAccuracy()
        } else {
          $.fn.latLonSelector.stopEditAccuracy()
        }
        
        $.fn.latLonSelector.updateFormAccuracy($(this).val(), {
          positioningMethod: 'manual', positioningDevice: 'manual'})
      })
    }
    
    var latitudeField = findFormField(input, 'latitude'),
        longitudeField = findFormField(input, 'longitude'),
        f = function() {
          var point = new google.maps.LatLng($(latitudeField).val(), $(longitudeField).val())
          getMarker().setPosition(point);
          $.fn.latLonSelector._map.setCenter(point)
          if ($.fn.latLonSelector._circle) {
            $.fn.latLonSelector._circle.setCenter(point)
          }
        }
    $(latitudeField).change(f)
    $(longitudeField).change(f)
  }
  
  function findFormField(context, name, options) {
    var options = $.extend({}, options);
    var tagName = options['tagName'] ? options['tagName'] : 'input';
    
    // Try to find among siblings and descendants
    var field = $(context).parent().find(tagName+'[name="'+name+'"]:first');
    if ($(field).length == 0) {
      field = $(context).parent().find(tagName+'[name*="['+name+']"]:first');
    };
    
    // Try to find within the same form
    if ($(field).length == 0) {
      field = $(context).parents('form').find(tagName+'[name="'+name+'"]:first');
    }
    if ($(field).length == 0) {
      field = $(context).parents('form').find(tagName+'[name*="['+name+']"]:first');
    };
    
    return field;
  }
  
  function logMessage() {
    if (typeof(console) != 'undefined') {
      try {
        return console.log.apply(null, arguments);
      } catch(e) {
        alert.apply("An error occurred while logging an error.  This was " + 
                    "too meta to handle so I crashed: " + e);
      };
    } else {
      alert("Console not defined!");
      return alert.apply(null, arguments);
    }
    return false;
  }
  
  // function handleMapClick(overlay, point) {
  $.fn.latLonSelector.handleMapClick = function(e) {
    handleMapClick(e)
  }
  function handleMapClick(e) {
    var map = $.fn.latLonSelector._map,
        input = $.fn.latLonSelector._currentInput,
        marker = getMarker({exact: true}),
        point = e.latLng
    
    // Move the marker
    marker.setPosition(point);
    
    // Update the form fields
    $.fn.latLonSelector.updateFormLatLon(point.lat(), point.lng());
    $(findFormField($.fn.latLonSelector._currentInput, 'positioning_method')).val('manual')
    $(findFormField($.fn.latLonSelector._currentInput, 'positioning_device')).val('manual')
    if ($.fn.latLonSelector._circle) {
      $.fn.latLonSelector._circle.setCenter(marker.getPosition())
      if (!$.fn.latLonSelector._circle.getEditable()) {
        $.fn.latLonSelector.setAccuracy(null)
        $.fn.latLonSelector.updateFormAccuracy(null)
      }
    }
  }
  
  function getMarker(options) {
    $.fn.latLonSelector._exactMarker.setVisible(true)
    return $.fn.latLonSelector._exactMarker;
  }
  
  function getGeocoder() {
    if (typeof $.fn.latLonSelector._geocoder == 'undefined') {
      $.fn.latLonSelector._geocoder = new google.maps.Geocoder();
    }
    return $.fn.latLonSelector._geocoder;
  }
  
  function getCurrentInput() {
    return $.fn.latLonSelector._currentInput;
  }
  
  function setExact(isExact) {
    if (typeof(isExact) == 'undefined') {
      var isExact = true;
    }
    
    // Set the marker to the exact marker
    $('#latLonSelector').find('#latLonSelectorExactFlag').get(0).checked = isExact;
    
    // Update the form
    $.fn.latLonSelector.updateFormExact(isExact);
    
    return false;
  }
  
  $.fn.latLonSelector.updateFormLatLon = function(lat, lon) {
    var input = $.fn.latLonSelector._currentInput;
    var latField = findFormField(input, 'latitude');
    var lonField = findFormField(input, 'longitude');
    $(latField).val(lat);
    $(lonField).val(lon);
    
    // Set the scale
    $.fn.latLonSelector.updateFormScale();
    
    // Set the approx location flag
    $.fn.latLonSelector.updateFormExact();
    
    return false;
  };
  
  $.fn.latLonSelector.updateFormScale = function(scale) {
    var input = $.fn.latLonSelector._currentInput;
    var scale = scale || $.fn.latLonSelector._map.getZoom();
    var scaleField = findFormField(input, 'map_scale');
    $(scaleField).val(scale);
  };
  
  $.fn.latLonSelector.updateFormExact = function(isExact) {
    var input = $.fn.latLonSelector._currentInput;
    var isExact = isExact || $('#latLonSelector').find(
                              '#latLonSelectorExactFlag:checked').length == 1;
    var locExactField = findFormField(input, 'location_is_exact');
    $(locExactField).val(isExact);
    $(locExactField).get(0).checked = isExact;
  };
  
  $.fn.latLonSelector.updateFormAccuracy = function(accuracy, options) {
    options = options || {}
    accuracy = parseInt(accuracy) || 0
    var input = $.fn.latLonSelector._currentInput,
        accuracyField = findFormField(input, 'positional_accuracy'),
        methodField = findFormField(input, 'positioning_method'),
        deviceField = findFormField(input, 'positioning_device'),
        positioningMethod = options.positioningMethod || $(methodField).val(),
        positioningDevice = options.positioningDevice || $(deviceField).val()
    $(accuracyField).val(accuracy || '')
    $(methodField).val(positioningMethod || '')
    $(deviceField).val(positioningDevice || '')
  };
  
  $.fn.latLonSelector.showMap = function(input) {
    var wrapper = $('#latLonSelector'),
        latField = findFormField(input, 'latitude'),
        lonField = findFormField(input, 'longitude'),
        scaleField = findFormField(input, 'map_scale'),
        exactField = findFormField(input, 'location_is_exact'),
        accuracyField = findFormField(input, 'positional_accuracy'),
        mapDiv = $('.latLonSelectorMap:first')
    $.fn.latLonSelector._currentInput = input
    
    // Move the map to the bottom of the input
    $(wrapper).css({
      left: $(input).offset().left,
      top: $(input).offset().top + $(input).outerHeight() - 1,
      width: $(input).innerWidth()
    });
    
    // Show it
    $(wrapper).fadeIn();
    
    // If not container, move the map
    if (typeof($.fn.latLonSelector._options.mapDiv) == 'undefined') {
      $(mapDiv).css({
        width: $(input).innerWidth(),
        height: $(input).innerWidth()
      });

      // Notify Google
      google.maps.event.trigger($.fn.latLonSelector._map, 'resize')
      $.fn.latLonSelector._map.setCenter(new google.maps.LatLng(0,0))
    };
    
    // Get marker, exact or approx based on exactField
    var isExact = $(exactField).get(0).checked == true;
    var marker = getMarker({exact: isExact});
    setExact(isExact)
    
    // Set the map's scale
    var scale = parseInt($(scaleField).val())
    if (scale && scale != 0) {
      input._lastScale = input._lastScale || scale
      $.fn.latLonSelector._map.setZoom(input._lastScale)
    }
    
    // If lat and lon set, center the map and add a marker (or move the existing one)
    if ($(latField).val() != '' && $(lonField).val() != '') {
      marker.setPosition(new google.maps.LatLng($(latField).val(), $(lonField).val()));
      $.fn.latLonSelector._map.setCenter(marker.getPosition(), scale);
      if (accuracyField && $(accuracyField).val()) {
        $.fn.latLonSelector.setAccuracy($(accuracyField).val())
      }
    }
    // Otherwise hide it
    else {
      marker.setVisible(false);
    }
  };
  
  $.fn.latLonSelector.hideMap = function(options) {
    var options = $.extend({}, options);
    if (options.effect && options.effect == 'none') {
      $('#latLonSelector').setVisible(false);
    } else {
      $('#latLonSelector').fadeOut();
    };
  };
  
  $.fn.latLonSelector.lookup = function(q) {
    var map = $.fn.latLonSelector._map;
    var marker = getMarker({exact: false});
    var parsedLatLon = $.fn.latLonSelector.parseLatLon(q)
    var self = this
    if (parsedLatLon) {
      var point = new google.maps.LatLng(
        parsedLatLon[0],
        parsedLatLon[1]
      );
      marker.setPosition(point);
      $.fn.latLonSelector._map.setCenter(point);
      $.fn.latLonSelector.updateFormLatLon(parsedLatLon[0], parsedLatLon[1]);
      setExact(true)
      return
    }
    
    var geocoder = getGeocoder();
    geocoder.geocode({address: q}, function(results, status) {
      if (status != google.maps.GeocoderStatus.OK) {
        alert("Google couldn't find '" + q + "'");
        return;
      }
      
      var result = results[0]
      
      if (results[0].geometry.location_type == google.maps.GeocoderLocationType.ROOFTOP) {
        marker = getMarker.call(self, {exact: true})
        setExact.call(self, true)
      }
      var point = results[0].geometry.location
      marker.setPosition(point);

      $.fn.latLonSelector._map.setCenter(point);
      $.fn.latLonSelector._map.fitBounds(results[0].geometry.viewport)
      
      $.fn.latLonSelector.updateFormLatLon(
        marker.getPosition().lat(), 
        marker.getPosition().lng()
      )
      
      var bounds = result.geometry.bounds || result.geometry.viewport
      if (bounds) {
        var dNorthEast = iNaturalist.Map.distanceInMeters(point.lat(), point.lng(), 
              bounds.getNorthEast().lat(), bounds.getNorthEast().lng()),
            dSouthWest = iNaturalist.Map.distanceInMeters(point.lat(), point.lng(), 
              bounds.getSouthWest().lat(), bounds.getSouthWest().lng()),
            accuracy = Math.max(dNorthEast, dSouthWest)
        $.fn.latLonSelector.setAccuracy(accuracy, {lat: point.lat(), lng: point.lng()})
        $.fn.latLonSelector.updateFormAccuracy(accuracy, {positioningMethod: 'google', positioningDevice: 'google'})
      }
    });
  };
  
  $.fn.latLonSelector.updateAccuracyWithGeocoderResult = function(result) {
    var d = iNaturalist.Map.distanceInMeters(
      bounds.getCenter().lat(), bounds.getCenter().lng(), 
      bounds.getNorthEast().lat(), bounds.getNorthEast().lng())
    $.fn.latLonSelector.setAccuracy(d, {lat: bounds.getCenter().lat(), lng: bounds.getCenter().lng()})
  }
  
  $.fn.latLonSelector.editAccuracy = function() {
    if (!$.fn.latLonSelector._circle) { 
      $.fn.latLonSelector.setAccuracy(null)
    }
    var bounds = $.fn.latLonSelector._map.getBounds(),
        center = bounds.getCenter(), 
        northEast = bounds.getNorthEast(),
        mapAcc = iNaturalist.Map.distanceInMeters(center.lat(), center.lng(), northEast.lat(), northEast.lng()) / 5,
        defaultAcc = Math.max(mapAcc, 20),
        defaultAcc = Math.min(mapAcc, 100000),
        accuracyField = findFormField($.fn.latLonSelector._currentInput, 'positional_accuracy'),
        acc = $(accuracyField).val() || defaultAcc
    $.fn.latLonSelector.setAccuracy(acc)
    $.fn.latLonSelector.updateFormAccuracy($.fn.latLonSelector._circle.getRadius(), {
      positioningMethod: 'manual', 
      positioningDevice: 'manual'})
      
    $.fn.latLonSelector._circle.setOptions({
      editable: true,
      visible: true,
      fillOpacity: 0.35
    })
  }
  
  $.fn.latLonSelector.stopEditAccuracy = function() {
    if (!$.fn.latLonSelector._circle) { return }
    $.fn.latLonSelector._circle.setOptions({
      editable: false,
      fillOpacity: 0
    })
  }
  
  $.fn.latLonSelector.toggleEditAccuracy = function() {
    if ($.fn.latLonSelector._circle && $.fn.latLonSelector._circle.getEditable()) {
      $.fn.latLonSelector.stopEditAccuracy()
    } else {
      $.fn.latLonSelector.editAccuracy()
    }
  }
  
  $.fn.latLonSelector.setAccuracy = function(accuracy, options) {
    options = options || {}
    if (!$.fn.latLonSelector._circle) {
      $.fn.latLonSelector._circle = new google.maps.Circle({
        strokeColor: "#882A28",
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: "#FF6963",
        fillOpacity: 0,
        editable: false,
        map: $.fn.latLonSelector._map
      })
      
      google.maps.event.addListener($.fn.latLonSelector._circle, 'radius_changed', function() {
        if (!this._nonManualRadiusChange) {
          $.fn.latLonSelector.updateFormAccuracy(this.getRadius(), {positioningMethod: 'manual', positioningDevice: 'manual'})
        }
        this._nonManualRadiusChange = false
      })
      google.maps.event.addListener($.fn.latLonSelector._circle, 'center_changed', function() {
        $.fn.latLonSelector.currentMarker().setPosition(this.getCenter())
        if (this.getCenter()) {
          $.fn.latLonSelector.updateFormLatLon(this.getCenter().lat(), this.getCenter().lng())
        }
      })
      google.maps.event.addListener($.fn.latLonSelector._circle, 'click', function(e) {
        var circleBounds = this.getBounds(),
            mapBounds = $.fn.latLonSelector._map.getBounds()
        if (circleBounds.contains(mapBounds.getNorthEast()) && circleBounds.contains(mapBounds.getSouthWest())) {
          handleMapClick(e)
        } else {
          $.fn.latLonSelector.toggleEditAccuracy()
        }
      })
    }
    
    accuracy = parseInt(accuracy)
    if (accuracy && accuracy != 0) {
      $.fn.latLonSelector._circle.setVisible(true)
      $.fn.latLonSelector._circle._nonManualRadiusChange = true
      $.fn.latLonSelector._circle.setRadius(accuracy)
    } else {
      $.fn.latLonSelector._circle.setEditable(false)
      $.fn.latLonSelector._circle.setVisible(false)
    }
    
    if ($.fn.latLonSelector.currentMarker()) {
      $.fn.latLonSelector._circle.setCenter($.fn.latLonSelector.currentMarker().getPosition())
    }
  }
  
  $.fn.latLonSelector.currentMarker = function() {
    return $.fn.latLonSelector._exactMarker.getVisible() ? $.fn.latLonSelector._exactMarker : $.fn.latLonSelector._approxMarker
  }
  
  $.fn.latLonSelector.accuracyToZoom = function(accuracy) {
    var dict = {
      0: 0,   // Unknown location. (Since 2.59)
      1: 2,   // Country level accuracy. (Since 2.59)
      2: 4,   // Region (state, province, prefecture, etc.) level accuracy. (Since 2.59)
      3: 5,   // Sub-region (county, municipality, etc.) level accuracy. (Since 2.59)
      4: 8,   // Town (city, village) level accuracy. (Since 2.59)
      5: 9,   // Post code (zip code) level accuracy. (Since 2.59)
      6: 10,  // Street level accuracy. (Since 2.59)
      7: 11,  // Intersection level accuracy. (Since 2.59)
      8: 12,  // Address level accuracy. (Since 2.59)
      9: 13   // Premise (building name, property name, shopping center, etc.) level accuracy. (Since 2.105)
    };
    return dict[accuracy];
  };
  
  $.fn.latLonSelector.COORDINATE_REGEX = /[-+]?[0-9]*\.?[0-9]+/g;
  $.fn.latLonSelector.parseLatLon = function(latLon) {
    if (!latLon || latLon == '' || latLon.match(/[a-cf-mo-rt-vx-z]/i)) { return }
    var matches = latLon.match(this.COORDINATE_REGEX),
        lat, lon
    switch(matches.length) {
      case 2:
        lat = parseFloat(matches[0])
        lon = parseFloat(matches[1])
        break;
      case 4:
        lat = parseInt(matches[0]) + parseFloat(matches[1])/60.0
        lon = parseInt(matches[3]) + parseFloat(matches[4])/60.0
      case 6:
        lat = parseInt(matches[0]) + parseInt(matches[1])/60.0 + parseFloat(matches[2])/60/60
        lon = parseInt(matches[3]) + parseInt(matches[4])/60.0 + parseFloat(matches[5])/60/60
        break;
      default:
        return
    }
    if (lat > 0 && latLon.match(/s/i)) {lat *= -1}
    if (lon > 0 && latLon.match(/w/i)) {lon *= -1}
    return [lat,lon]
  };
  
  $.fn.latLonSelector.defaults = {
    buttonImgPath: '/images/silk/world.png',
    wrapperCSS: {
      display: 'none',
      position: 'absolute',
      'border-color': '#ccc',
      'border-width': '1px',
      'border-style': 'solid',
      'background-color': 'white'
    },
    mapCSS: {
      width: '100%',
      height: '300px',
      overflow: 'hidden',
      clear: 'both',
      'border-top': '1px solid #ccc',
      'border-bottom': '1px solid #ccc'
    },
    buttonCSS: {
      'position': 'relative',
      'top': '-1px',
      'float': 'left',
      'font-weight': 'bold',
      'background-color': 'white',
      'border-right': '1px solid #ccc',
      'border-bottom': '1px solid #ccc',
      'border-top': '1px solid white',
      'padding': '0 0.5em'
    },
    closeCSS: {
      'background-color': '#ccc',
      'font-weight': 'bold',
      'text-align': 'center',
      'padding': '2px 0.5em 3px'
    },
    closeText: '&times;'
  };
  $.fn.latLonSelector.defaults.containedWrapperCSS = $.extend({},
    $.fn.latLonSelector.defaults.wrapperCSS, {
      display: 'block',
      position: 'static'
    }
  );
})(jQuery);
