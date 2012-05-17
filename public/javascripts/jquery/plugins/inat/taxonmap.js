(function($){
  $.fn.taxonMap = function(options) {
    options = options || {}
    $(this).each(function() {
      if (options == 'fit') {
        fit(this)
      } else {
        setup(this, options)
      }
    })
  }
  
  function setup(elt, options) {
    var options = $.extend({}, options)
    options.taxonId = options.taxonId || $(elt).attr('data-taxon-id')
    if (!options.taxonId) { return }
    options.latitude = options.latitude || $(elt).attr('data-latitude')
    options.longitude = options.longitude || $(elt).attr('data-longitude')
    options.placeKmlUrl = options.placeKmlUrl || $(elt).attr('data-place-kml')
    if (options.placeKmlUrl == '') { options.placeKmlUrl = null }
    options.taxonRangeKmlUrl = options.taxonRangeKmlUrl || $(elt).attr('data-taxon-range-kml')
    if (options.taxonRangeKmlUrl == '') { options.taxonRangeKmlUrl = null }
    options.gbifKmlUrl = options.gbifKmlUrl || $(elt).attr('data-gbif-kml')
    if (options.gbifKmlUrl == '') { options.gbifKmlUrl = null }
    
    if (options.observationsJsonUrl != false) {
      options.observationsJsonUrl = options.observationsJsonUrl 
        || $(elt).attr('data-observations-json') 
        || observationsJsonUrl(options.taxonId)
    }
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
  
  function fit(elt) {
    if (true) {
      fitGoogle(elt)
    } else if (typeof(org) != 'undefined' && typeof(org.polymaps) != 'undefined') {
      fitPolymaps(elt)
    }
  }
  
  function setupGoogle(elt) {
    var options = $(elt).data('taxonMapOptions'),
        map = iNaturalist.Map.createMap({div: elt}),
        preserveViewport = options.preserveViewport
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
    
    if (options.gbifKmlUrl) {
      var gbifLyr = new google.maps.KmlLayer(options.gbifKmlUrl, {suppressInfoWindows: true, preserveViewport: true})
      map.addOverlay('GBIF Occurrences', gbifLyr, {
        id: 'gbif-'+options.taxonId, 
        hidden: true,
        description: 
          ['It may take Google a while ',
          'to load these data, ',
          'assuming GBIF has any. ',
          '<a target="_blank" href="'+options.gbifKmlUrl.replace(/&format=kml/, '')+'">Data URL</a>'].join('<br/>')
      })
      google.maps.event.addListener(gbifLyr, 'click', function(e) {
        if (!window['kmlInfoWindows']) window['kmlInfoWindows'] = {}
        for (var k in window['kmlInfoWindows']) {
          window['kmlInfoWindows'][k].close()
        }
        var win = window['kmlInfoWindows'][e.featureData.id]
        if (!win) {
          // filter out google's insane parsing
          var content = (e.featureData.description || '').replace(/(<a.+?>)<a.+?>(.+?)<\/a><\/a>/g, "$1$2</a>")
          content = content.replace(/&lt;\/a/g, '')
          content = content.replace(/&gt;/g, '')
          content = content.replace(/<\/a"/g, '"')
          win = window['kmlInfoWindows'][e.featureData.id] = new google.maps.InfoWindow({
            content: content, 
            position: e.latLng,
            pixelOffset: e.pixelOffset
          })
        }
        win.open(window.map)
        return false
      })
      preserveViewport = true
    }
    
    if (options.observationsJsonUrl) {
      $.get(options.observationsJsonUrl, function(data) {
        map.addObservations(data)
        if (!preserveViewport && map.observationBounds) {
          map.zoomToObservations()
          preserveViewport = true
        }
      })
    }
    
    if (!preserveViewport) {
      fit(elt)
    }
    
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map))
    
    $(elt).data('taxonMap', map)
  }
  
  function setupPolymaps(elt) {
    
  }
  
  function fitGoogle(elt) {
    var options = $(elt).data('taxonMapOptions'),
        map = $(elt).data('taxonMap'),
        preserveViewport = false
    if (!map) {return};
    if (options.bbox) {
      map.fitBounds(
        new google.maps.LatLngBounds(
          new google.maps.LatLng(options.bbox[0], options.bbox[1]),
          new google.maps.LatLng(options.bbox[2], options.bbox[3])
        )
      )
      return
    } else if (options.latitude || options.longitude) {
      map.setCenter(new google.maps.LatLng(options.latitutde || 0, options.longitude || 0))
      map.setZoom(4)
      return
    }

    if (options.taxonRangeKmlUrl) {
      var lyrInfo = map.getOverlay('Taxon Range')
      lyrInfo.overlay.setMap(null)
      lyrInfo.overlay.setMap(map)
      return
    }

    if (options.placeKmlUrl) {
      var lyrInfo = map.getOverlay('Place Boundary')
      lyrInfo.overlay.setMap(null)
      lyrInfo.overlay.setMap(map)
      return
    }

    if (options.observationsJsonUrl && map.observationBounds) {
      map.zoomToObservations()
      return
    }
    
    map.setCenter(new google.maps.LatLng(0, 0))
    map.setZoom(1)
  }
  
  function observationsJsonUrl(id) {
    return 'http://' + window.location.host + '/observations/of/'+id+'.json'
  }
}(jQuery))
