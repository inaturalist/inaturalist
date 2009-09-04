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
      getMarker().hide();
      return false;
    });
    var close = $('<a href="#">'+options.closeText+'</a>').css(
      options.closeCSS);
    $(close).click(function(e) {
      $.fn.latLonSelector.hideMap();
      return false;
    });
    $(controls).append(button, clear, close);
    $(wrapper).prepend(controls);
    
    // Setup the map
    if (typeof options.map != 'undefined') {
      var map = $.fn.latLonSelector._map = options.map;
    }
    else if (GBrowserIsCompatible()) {
      var map = $.fn.latLonSelector._map = new GMap2($(mapDiv).get(0));
      map.setCenter(new GLatLng(37.8, -122.2), 13);
      map.addControl(new GSmallMapControl());
      map.addControl(new GMenuMapTypeControl());
    } else {
      throw "Google Maps doesn't work with this browser."
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
    GEvent.addListener(map, 'click', handleMapClick);
    
    // Update scale field on zoomend
    GEvent.addListener(map, 'zoomend', function(oldZoom, newZoom) {
      $.fn.latLonSelector.updateFormScale(newZoom);
    });
    
    // Set the default markers
    if (typeof options.marker != 'undefined') {
      $.fn.latLonSelector._exactMarker = options.marker;
    }
    else if (GBrowserIsCompatible()) {
      $.fn.latLonSelector._exactMarker = new GMarker(new GLatLng(0,0), {
        draggable: true,
        bouncy: true,
        autoPan: true
      });
    } else {
      throw "Google Maps doesn't work with this browser.";
    };
    $.fn.latLonSelector._map.addOverlay($.fn.latLonSelector._exactMarker);
    $.fn.latLonSelector._exactMarker.hide();
    
    if (typeof options.approxMarker != 'undefined') {
      $.fn.latLonSelector._approxMarker = options.approxMarker;
    }
    else if (GBrowserIsCompatible()) {
      var circleIcon = new GIcon(G_DEFAULT_ICON, 
        'http://maps.google.com/intl/en_us/mapfiles/circle.png');
      circleIcon.shadow = 
        'http://maps.google.com/intl/en_us/mapfiles/circle-shadow45.png';
      $.fn.latLonSelector._approxMarker = new GMarker(new GLatLng(0,0), {
        icon: circleIcon,
        draggable: true,
        bouncy: true,
        autoPan: true
      });
    } else {
      throw "Google Maps doesn't work with this browser."
    };
    $.fn.latLonSelector._map.addOverlay($.fn.latLonSelector._approxMarker);
    $.fn.latLonSelector._approxMarker.hide();
    
    
    // Insert the data controls
    var dataControls = $('<div id="latLonSelectorDataControls"></div>');
    $(dataControls).css({
      color: '#888',
      clear: 'left'
    });
    $(dataControls).append(
      $('<input id="latLonSelectorExactFlag" type="checkbox"/>').click(
        function(e) {
        setExact(this.checked);
        getMarker({exact: this.checked});
      }),
      $('<label for="latLonSelectorExactFlag">Exact location</label>')
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
        try {
          if ($('#latLonSelector:visible').length == 0) {
            $(input).get(0).focus();
          } else {
            $.fn.latLonSelector.hideMap(input);
          };
        }
        catch (e) {
          logMessage(e);
        }
        return false;
      });
    };
    
    // Bind focus/blur to show the map
    $(input).focus(function(e) {
      try {
        if ($('#latLonSelector:visible').length == 0) {
          $.fn.latLonSelector.showMap(input);
        } else if ($.fn.latLonSelector._currentInput != input){
          $.fn.latLonSelector.showMap(input);
        }
      }
      catch (e) {
        logMessage(e);
      }
      return false;
    });
    
    // Bind ENTER in input to search the map
    $(input).keypress(function(e) {
      if (e.which == 13) {
        // Catch exceptions to ensure false return and precent form submission
        try {
          $.fn.latLonSelector.lookup($(input).val());
        }
        catch (e) {
          logMessage(e);
        }
        return false;
      };
    });
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
                    "too meta to handle so I crashed: ", e);
      };
    } else {
      alert("Console not defined!");
      return alert.apply(null, arguments);
    }
    return false;
  }
  
  function handleMapClick(overlay, point) {
    var map = $.fn.latLonSelector._map;
    var input = $.fn.latLonSelector._currentInput;
    var marker = getMarker({exact: true});
    
    // Move the marker
    marker.setLatLng(point);
    
    // Update the form fields
    $.fn.latLonSelector.updateFormLatLon(point.lat(), point.lng());
  }
  
  function getMarker(options) {
    var options = $.extend({}, options);
    var oldPoint;
    var marker;
    
    if (typeof options.exact == 'undefined') {
      if ($.fn.latLonSelector._exactMarker.isHidden()) {
        marker = $.fn.latLonSelector._approxMarker;
      } else {
        marker = $.fn.latLonSelector._exactMarker;
      }
    } else {
      if (options.exact == true) {
        setExact(true);
        if ($.fn.latLonSelector._exactMarker.isHidden()) {
          oldPoint = $.fn.latLonSelector._approxMarker.getPoint();
          $.fn.latLonSelector._approxMarker.hide();
          $.fn.latLonSelector._exactMarker.setLatLng(oldPoint);
        };
        marker = $.fn.latLonSelector._exactMarker;
      } else {
        setExact(false);
        if ($.fn.latLonSelector._approxMarker.isHidden()) {
          // Make the marker an approximate marker
          oldPoint = $.fn.latLonSelector._exactMarker.getPoint();
          $.fn.latLonSelector._exactMarker.hide();
          $.fn.latLonSelector._approxMarker.setLatLng(oldPoint);
        }
        marker = $.fn.latLonSelector._approxMarker;
      };
    }
    
    marker.show();
    
    // Bind dragend
    GEvent.clearListeners(marker, 'dragend');
    GEvent.addListener(marker, 'dragend', function() {
      // Drags indicate exact positioning
      setExact(true);
      getMarker({exact: true});
      
      $.fn.latLonSelector.updateFormLatLon(
        this.getLatLng().lat(), 
        this.getLatLng().lng()
      );
    });
    
    return marker;
  }
  
  function getGeocoder() {
    if (typeof $.fn.latLonSelector._geocoder == 'undefined') {
      $.fn.latLonSelector._geocoder = new GClientGeocoder();
    };
    return $.fn.latLonSelector._geocoder;
  }
  
  function getCurrentInput() {
    return $.fn.latLonSelector._currentInput;
  }
  
  function setExact(isExact) {
    if (typeof(isExact) == 'undefined') {
      var isExact = true;
    };
    
    // Set the marker to the exact marker
    $('#latLonSelector').find(
      '#latLonSelectorExactFlag').get(0).checked = isExact;
    
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
    // console.log("DEBUG: input: ", input);
    // console.log("DEBUG: locExactField: ", locExactField);
    $(locExactField).get(0).checked = isExact;
  };
  
  $.fn.latLonSelector.showMap = function(input) {
    var wrapper = $('#latLonSelector');
    var latField = findFormField(input, 'latitude');
    var lonField = findFormField(input, 'longitude');
    var scaleField = findFormField(input, 'map_scale');
    var exactField = findFormField(input, 'location_is_exact');
    var mapDiv = $('#latLonSelectorMap');
    $.fn.latLonSelector._currentInput = input;
    
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
      $.fn.latLonSelector._map.checkResize();
    };
    
    // Get marker, exact or approx based on exactField
    var isExact = $(exactField).get(0).checked == true;
    var marker = getMarker({exact: isExact});
    setExact(isExact);
    
    // Set the map's scale
    var scale;
    if ($(scaleField).val() != '') {
      var scale = parseInt($(scaleField).val());
    }
    
    // If lat and lon set, center the map and add a marker (or move the existing one)
    if ($(latField).val() != '' && $(lonField).val() != '') {
      marker.setLatLng(new GLatLng($(latField).val(), $(lonField).val()));
      $.fn.latLonSelector._map.setCenter(marker.getLatLng(), scale);
    }
    // Otherwise hide it
    else {
      marker.hide();
    }
    
    // Move the map above the input if necessary
    // if (($(map).position().top + $(map).outerHeight()) > $(window).height()) {
    //   $(map).css({
    //     top: $(input).offset().top - $(map).outerHeight()
    //   });
    // };
  };
  
  $.fn.latLonSelector.hideMap = function(options) {
    var options = $.extend({}, options);
    if (options.effect && options.effect == 'none') {
      $('#latLonSelector').hide();
    } else {
      $('#latLonSelector').fadeOut();
    };
  };
  
  $.fn.latLonSelector.lookup = function(q) {
    var map = $.fn.latLonSelector._map;
    var marker = getMarker({exact: false});
    var geocoder = getGeocoder();

    geocoder.getLocations(q, function(response) {
      if (response.Status.code == 602) {
        alert("Google couldn't find '" + q + "'");
      };
      if (response.Placemark) {
        var point = new GLatLng(
          response.Placemark[0].Point.coordinates[1],
          response.Placemark[0].Point.coordinates[0]
        );
        var zoom = $.fn.latLonSelector.accuracyToZoom(
          response.Placemark[0].AddressDetails.Accuracy);
        marker.setLatLng(point);

        $.fn.latLonSelector._map.setCenter(point, zoom);
        
        $.fn.latLonSelector.updateFormLatLon(
          marker.getLatLng().lat(), 
          marker.getLatLng().lng()
        );
      };
    });
  };
  
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
