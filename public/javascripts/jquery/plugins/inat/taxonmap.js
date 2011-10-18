(function($){
  $.fn.taxonMap = function(options) {
    options = options || {}
    $(this).each(function() {
      setup(this, options)
    })
  }
  
  function setup(elt, options) {
    var options = $.extend({}, options)
    options.taxonId = options.taxonId || $(elt).attr('data-taxon-id')
    if (!options.taxonId) { return }
    options.latitude = options.latitude || $(elt).attr('data-latitude')
    options.longitude = options.longitude || $(elt).attr('data-longitude')
    options.placeKmlUrl = options.placeKmlUrl || $(elt).attr('data-place-kml')
    options.taxonRangeKmlUrl = options.taxonRangeKmlUrl || $(elt).attr('data-taxon-range-kml')
    options.observationsJsonUrl = options.observationsJsonUrl || $(elt).attr('data-observations-json') || observationsJsonUrl(options.taxonId)
    options.bbox = options.bbox || $(elt).attr('data-bbox')
    if (typeof(options.bbox) == 'string') {
      options.bbox = $.map(options.bbox.split(','), Number)
    }
    $(elt).data('taxonMapOptions', options)
    // if ($.browser.msie && typeof(google) != 'undefined') {
    if (true) {
      setupGoogle(elt)
    } else if (typeof(org) != 'undefined' && typeof(org.polymaps) != 'undefined') {
      setupPolymaps(elt)
    }
  }
  
  function setupGoogle(elt) {
    var options = $(elt).data('taxonMapOptions'),
        map = iNaturalist.Map.createMap({div: elt}),
        preserveViewport = false
    if (options.bbox) {
      map.fitBounds(
        new google.maps.LatLngBounds(
          new google.maps.LatLng(options.bbox[0], options.bbox[1]),
          new google.maps.LatLng(options.bbox[2], options.bbox[3])
        )
      )
      preserveViewport = true
    } else if (options.latitude || options.longitude) {
      map.setCenter(new google.maps.LatLng(options.latitutde || 0, options.longitude || 0))
    }
    
    if (options.taxonRangeKmlUrl) {
      var taxonRangeLyr = new google.maps.KmlLayer(options.taxonRangeKmlUrl, {suppressInfoWindows: true, preserveViewport: preserveViewport})
      map.addOverlay('Taxon Range', taxonRangeLyr, {id: 'taxon_range-'+options.taxonId})
      preserveViewport = true
    }
    
    if (options.placeKmlUrl) {
      var placeLyr = new google.maps.KmlLayer(options.placeKmlUrl, {suppressInfoWindows: true, preserveViewport: preserveViewport})
      map.addOverlay('Place Boundary', placeLyr, {id: 'place_boundary-'+options.taxonId})
      preserveViewport = true
    }
    
    if (options.observationsJsonUrl) {
      $.get(options.observationsJsonUrl, function(data) {
        map.addObservations(data)
      })
    }
    
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map))
    
    $(elt).data('taxonMap', map)
  }
  
  function setupPolymaps(elt) {
    
  }
  
  function observationsJsonUrl(id) {
    return 'http://' + window.location.host + '/observations/of/'+id+'.json'
  }
}(jQuery))
