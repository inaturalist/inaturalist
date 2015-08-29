window.colorScale = d3.scale.category10()
function classifyCounties(e) { classifyPlaces(e, {placeType: 'county'}) }
function classifyStates(e) { classifyPlaces(e, {placeType: 'state'}) }
function classifyCountries(e) { classifyPlaces(e, {placeType: 'country'}) }
function classifyPlaces(e, options) {
  var options = options || {},
      placeType = options.placeType || 'county'
  for (var i = e.features.length - 1; i >= 0; i--){
    var feature = e.features[i]
    if (feature.data.properties) {
      var placeId = feature.data.properties.place_id
    } else {
      continue
    }
    var listing
    switch (placeType) {
      case 'county':
        listing = countyListings[placeId]
        break;
      case 'state':
        listing = stateListings[placeId]
        break;
      case 'country':
        listing = countryListings[placeId]
        break;
    }
    if (listing) {
      var placeClass = 'place_' + listing.place_id
      var cssClass = [placeType, placeClass, listing.establishment_means].join(' ')
      if (listing.last_observation_id) {
        cssClass += ' confirmed'
      } else if (listing.occurrence_status == 'absent') {
        cssClass += ' absent'
      } else {
        cssClass += ' putative'
      }
      feature.element.setAttribute('class',  cssClass)
      feature.element.setAttribute('data-place-id', listing.place_id)
      $(feature.element).hover(
        function() { $('path.place_'+$(this).attr('data-place-id')).css('opacity', 0.7) },
        function() { $('path.place_'+$(this).attr('data-place-id')).css('opacity', 0.5) }
      )
      
      $(feature.element).qtip({
        style: {
          classes: 'listed_taxon ui-tooltip-light ui-tooltip-shadow'
        },
        show: {
          event: 'click',
          solo: true
        },
        hide: {
          event: 'unfocus'
        },
        position: {
          viewport: $(window),
          my: 'bottom center',
          at: 'center center'
        },
        content: {
          title: {
            text: 'Listed taxon',
            button: true
          },
          text: '<span class="meta loading status">Loading..</span>',
          ajax: {
            url: '/listed_taxa/'+listing.id,
            method: 'GET',
            data: {partial: 'place_tip'}
          }
        }
      })
    }
  }
}
function handleObservations(e) {
  for (var i = e.features.length - 1; i >= 0; i--){
    var feature = e.features[i]
    if (!feature || !feature.element) {continue}
    feature.element.setAttribute('data-observation-id', feature.data.properties.observation_id || feature.data.properties.id)
    var cssClass = feature.data.properties.quality_grade
    if (feature.data.properties.quality_grade == 'research' || feature.data.properties.quality_grade == 'community') {
      cssClass += ' confirmed'
    } else {
      cssClass += ' putative'
    }
    
    if (feature.data.properties.coordinates_obscured) {
      cssClass += ' obscured'
      var r = map.locationPoint({lat:0,lon:OBSCURATION_DISTANCE_IN_DEGREES}).x - map.locationPoint({lat:0,lon:0}).x
      if (r > 4.5) {
        feature.element.setAttribute('r', r)
      }
    } else if (feature.data.properties.positional_accuracy) {
      var accuracyInDegrees = feature.data.properties.positional_accuracy / PLANETARY_RADIUS * DEGREES_PER_RADIAN
      feature.element.setAttribute('radius-meters', feature.data.properties.positional_accuracy)
      var r = map.locationPoint({lat:0,lon:accuracyInDegrees}).x - map.locationPoint({lat:0,lon:0}).x
      if (r > 4.5) {
        feature.element.setAttribute('r', r)
      }
    }
    
    feature.element.setAttribute('class', cssClass)
    $(feature.element).qtip({
      style: {
        classes: 'mini infowindow observations ui-tooltip-light ui-tooltip-shadow'
      },
      show: {
        event: 'click',
        solo: true
      },
      hide: {
        event: 'unfocus'
      },
      position: {
        viewport: $(window),
        my: 'bottom center',
        at: 'center center'
      },
      content: {
        title: {
          text: 'Observation',
          button: true
        },
        text: '<span class="meta loading status">Loading..</span>',
        ajax: {
          url: '/observations/'+feature.data.properties.id,
          method: 'GET',
          data: {partial: 'cached_component'}
        }
      },
      events: {
        show: function(event, api) {
          if (window.map.size().x < 450) {
            api.elements.tooltip.width('260px').addClass('compact')
          } else {
            api.elements.tooltip.width('425px').removeClass('compact')
          }
        }
      }
    })
  }
}
function styleRange(e, child) {
  var fill = colorScale(child.id)
  var stroke = d3.rgb(fill).darker().toString()
  for (var i = e.features.length - 1; i >= 0; i--){
    var feature = e.features[i]
    feature.element.setAttribute('fill', fill)
    feature.element.setAttribute('stroke', stroke)
  }
}

function styleObservations(e, child) {
  var fill = colorScale(child.id)
  var stroke = fill.darken()
}

function addPlaces() {
  layers['countries_simple'] = po.geoJson()
    .id('countries_simple')
    .visible(false)
    .url(TILESTACHE_SERVER+"/countries_simplified/{Z}/{X}/{Y}.geojson")
    .on('load', classifyCountries)
  map.add(layers['countries_simple']);
  
  layers['states_simple'] = po.geoJson()
    .id('states_simple')
    .visible(false)
    .zoom(function(z) {
      if (z < 4) { 
        $('#place_type_states').attr('disabled', true)
        return -100
      }
      $('#place_type_states').attr('disabled', false)
      return z
    })
    .url(TILESTACHE_SERVER+"/states_simplified/{Z}/{X}/{Y}.geojson")
    .on('load', classifyStates)
  map.add(layers['states_simple']);
  
  layers['counties_simple'] = po.geoJson()
    .id('counties_simple')
    .visible(false)
    .zoom(function(z) {
      if (z < 7) { 
        $('#place_type_counties').attr('disabled', true)
        return -100
      }
      $('#place_type_counties').attr('disabled', false)
      return z;
    })
    .url(TILESTACHE_SERVER+"/counties_simplified/{Z}/{X}/{Y}.geojson")
    .on('load', classifyCounties)
  map.add(layers['counties_simple']);
  
  layers['counties'] = po.geoJson()
    .id('counties')
    .visible(false)
    .zoom(function(z) {
      if (z < 12) { return -100 }
      return z;
    })
    .url(TILESTACHE_SERVER+"/counties/{Z}/{X}/{Y}.geojson")
    .on('load', classifyCounties)
  map.add(layers['counties']);
  
  window.map.on('move', onZoom)
  showPlacesByZoom()
}

function onZoom() {
  if (window.lastZoom == map.zoom()) {
    return
  }
  showPlacesByZoom()
  window.lastZoom = map.zoom()
}

function showPlacesByZoom(options) {
  options = options || {}
  if (!options.force) {
    if (!$('#places_check'). prop('checked')) {
      return
    }
  }
  var lyr
  for (var lyrName in layers) {
    lyr = layers[lyrName]
    switch (lyrName) {
      case 'countries_simple':
        if (map.zoom() < 4) { 
          lyr.visible(true)
          $('#place_type_countries'). prop('checked', true)
        }
        else { lyr.visible(false) }
        break;
      case 'states_simple':
        if (map.zoom() >= 4 && map.zoom() < 7) { 
          lyr.visible(true)
          $('#place_type_states'). prop('checked', true)
        }
        else { lyr.visible(false) }
        break;
      case 'counties_simple':
        if (map.zoom() >= 7 && map.zoom() < 12) { 
          lyr.visible(true)
          $('#place_type_counties'). prop('checked', true)
        }
        else { lyr.visible(false) }
        break;
      case 'counties':
        if (map.zoom() >= 12) { 
          lyr.visible(true)
          $('#place_type_counties'). prop('checked', true)
        }
        else { lyr.visible(false) }
        break;
    }
  }
}

function addObservations() {
  layers['observations'] = po.geoJson()
    .id('observations')
    .url(observationsGeoJsonUrl)
    .tile(false)
    .on('load', handleObservations)
    .zoom(function(z) {
      $('#observations circle').each(function(o) {
        var r = parseFloat($(this).attr('r')),
            minDimension = Math.min(window.map.size().x, window.map.size().y)
        if (r * 2 > minDimension) {
          $(this).hide()
        } else {
          $(this).show()
        }
      })
      return z
    })
    .clip(false)
  map.add(layers['observations']);
}

function scaleLegend() {
  if ($('#legend').hasClass('collapsed') || $('#legend').hasClass('expanded')) {
    return
  }
  var scaleWidth  = $('#legend').data('originalOuterWidth') > $(window).width() / 2,
      scaleHeight = $('#legend').data('originalOuterHeight') > $(window).height() / 2
  if (scaleWidth || scaleHeight) {
    collapseLegend()
  } else {
    expandLegend()
  }
  window.windowResized = null
}

window.windowResizeHandler = function() {
  var now = (new Date()).getTime()
  if (windowResized && now - windowResized > 400) {
    scaleLegend()
  }
}

$(window).resize(function() {
  window.windowResized = (new Date()).getTime()
  setTimeout('windowResizeHandler()', 500)
})

$(document).ready(function() {
  window.layers = {}
  window.po = org.polymaps
  window.map = po.map()
    .container($('#map').get(0).appendChild(po.svg('svg')))
    .zoomRange([2, 15])
    .add(po.interact());
  if (window.location.hash.length > 0) {
    // let the po.hash() control handle it
  } else if (extent) {
    map.extent(extent).zoomBy(-0.5)
  } else {
    map.center({lat: 0, lon: 0}).zoom(3)
  }
  
  map.add(po.hash())
  
  if (CLOUDMADE_KEY) {
    window.mapLyr = po.image()
        .url(po.url("http://{S}tile.cloudmade.com"
        + "/"+CLOUDMADE_KEY
        + "/998/256/{Z}/{X}/{Y}.png")
        .hosts(["a.", "b.", "c.", ""]))
    map.add(cloudmadeLyr);
    $('#copyright').append(
      $('<span id="cloudmade_attribution"></span>').append(
        "Base map: &copy; <a href='http://www.openstreetmap.org/'>OpenStreetMap</a> contributors " + 
        "(<a href='http://opendatacommons.org/licenses/odbl/'>ODbL</a>), " + 
        "provided by <a href='http://cloudmade.com/'>CloudMade</a>"
      )
    )
  } else {
    window.mapLyr = po.image()
        .url(po.url("http://otile{S}.mqcdn.com/tiles/1.0.0/map/{Z}/{X}/{Y}.jpg")
        .hosts(["1", "1", "3", "4"]))
    map.add(mapLyr);
    $('#copyright').append(
      $('<span id="maplyr_attribution"></span>').append(
        "Base map: &copy; <a href='http://www.openstreetmap.org/'>OpenStreetMap</a> contributors " + 
        "(<a href='http://opendatacommons.org/licenses/odbl/'>ODbL</a>), " + 
        "tiles courtesy of <a href='http://www.mapquest.com/'' target='_blank'>MapQuest</a> " + 
        "<img src='http://developer.mapquest.com/content/osm/mq_logo.png'>"
      )
    )
  }
  
  if (BING_KEY) {
    var script = document.createElement("script");
    script.setAttribute("type", "text/javascript");
    script.setAttribute("src", "http://dev.virtualearth.net"
        + "/REST/V1/Imagery/Metadata/AerialWithLabels"
        + "?key="+BING_KEY
        + "&jsonp=bingCallback");
    document.body.appendChild(script);
    if (!window.mapLyr) {
      $('#controls').hide()
    }
  } else {
    // $('#basemap').hide()
    window.satLyr = po.image()
        .url(po.url("http://otile{S}.mqcdn.com/tiles/1.0.0/sat/{Z}/{X}/{Y}.jpg")
        .hosts(["1", "1", "3", "4"]))
    map.add(satLyr);
    $('#copyright').append(
      $('<div id="satlyr_attribution"></div>').append(
        "Base map: portions courtesy NASA/JPL-Caltech and U.S. Depart. of Agriculture, Farm Service Agency, " + 
        "tiles courtesy of <a href='http://www.mapquest.com/'' target='_blank'>MapQuest</a> " + 
        "<img src='http://developer.mapquest.com/content/osm/mq_logo.png'>"
      )
    )
    loadLayers()
    bindControls()
    $('#basemap_map').click()
  }
})

function loadLayers() {
  if (children && children.length > 0) {
    loadLayersForTaxa(children)
  } else if (taxa && taxa.length > 0) {
    loadLayersForTaxa(taxa)
  } else if (observationsJsonUrl)  {
    loadSingleTaxonLayers()
  }
  
  if (placeGeoJsonUrl) {
    map.add(po.geoJson()
      .id('place')
      .url(placeGeoJsonUrl)
      .on('load', classifyPlaces))
  };
  
  map.add(po.compass())
  $('#legendcontent').data('originalWidth',  $('#legendcontent').width())
  $('#legendcontent').data('originalHeight', $('#legendcontent').height())
  $('#legend').data('originalOuterWidth', $('#legend').outerWidth())
  $('#legend').data('originalOuterHeight', $('#legend').outerHeight())
  scaleLegend()
  
  // open links in the parent window if this is an iframe
  if (self != top) {
    $('a').on('click', function() {
      if ($(this).attr('href') == '#') {
        return
      }
      $(this).attr('target', '_blank')
    })
  }
}

function loadLayersForTaxa(taxa) {
  $('#legend ul').html('')
  var styling = po.stylist()
    .style('visibility', 'visible')
    .style('fill', function(f) { return colorScale(f.properties.taxon_id) })
    .style('stroke', function(f) { return d3.rgb(colorScale(f.properties.taxon_id)).darker().toString() })
    .attr('class', 'range')
  
  var names = taxa.map(function(t) {return t.name}).unique()
  var addIds = names.length < taxa.length;
    
  $.each(taxa, function() {
    var taxon = this,
        rangeId = 'range_'+taxon.id,
        observationsId = 'observations_'+taxon.id;
    if (taxon.range_url) {
      layers[rangeId] = po.geoJson()
        .id(rangeId)
        .url(taxon.range_url)
        .tile(false)
        .clip(false)
        .on('load', styling)
      map.add(layers[rangeId])
    }

    var inputId = 'taxon_check_' + taxon.id
    var input = $('<input type="checkbox">')
      .attr('id', inputId)
      . prop('checked', 'checked')
      .click(function() { 
        if (layers[rangeId]) { layers[rangeId].visible(this.checked); }
        layers[observationsId].visible(this.checked)
      })
    var symbol = $('<div class="symbol"></div>').css({
      backgroundColor: colorScale(taxon.id),
      borderColor: d3.rgb(colorScale(taxon.id)).darker().toString(),
      borderStyle: 'solid',
      borderWidth: '1px'
    })
    var nameContent = addIds ? taxon.name + ' ' + taxon.id : taxon.name
    var label = $('<label></label>').attr('for', inputId).html(nameContent)
    if (taxon.is_active == false) {label.addClass('inactive').attr("title", "Inacive taxon concept")};
    var link = $('<a></a>').attr('href', '/taxa/'+taxon.id).html('(view)').addClass('small')
    var li = $('<li></li>').append(input, ' ', symbol, ' ', label, ' ', link)
    $('#legend ul').append(li)
  })
  
  $.each(taxa, function() {
    var taxon = this,
        rangeId = 'range_'+taxon.id,
        observationsId = 'observations_'+taxon.id;
    layers[observationsId] = po.geoJson()
      .id(observationsId)
      .url(taxon.observations_url)
      .tile(false)
      .clip(false)
      .on('load', handleObservations)
      .on('load', styling)
    map.add(layers[observationsId])
  })
}

function loadSingleTaxonLayers() {
  if (taxonRangeUrl) {
    layers['range'] = po.geoJson()
      .id('range')
      .tile(false)
      .url(taxonRangeUrl)
    map.add(layers['range'])
    $('#copyright').append(
      $('<span id="range_attribution"></span>').append(
        'Taxon range: ',
        taxonRange.source ? (taxonRange.source.citation || taxonRange.source.title) : 'unknown source'
      ).autolink()
    )
  }
  addPlaces()
  addObservations()
  
  // layer toggles
  $('#legend li').each(function() {
    if ($(this).attr('rel')) {
      var targetLayers = $(this).attr('rel').split(' ')
    } else {
      return
    }
    
    $(this).find('input[type=checkbox]').click(function() {
      if ($(this).attr('id') == 'places_check' && this.checked) {
        showPlacesByZoom({force: true})
      } else {
        for (var i = targetLayers.length - 1; i >= 0; i--){
          if (layers[targetLayers[i]]) { layers[targetLayers[i]].visible(this.checked) }
        }
      }
    })
  })
  
  var radios = $('#legend input[type=radio]'),
      exclusiveLayers = radios.map(function() { return $(this).parents('li').attr('rel').split(' ') })
  radios.click(function() {
    for (var i = exclusiveLayers.length - 1; i >= 0; i--){
      layers[exclusiveLayers[i]].visible(false)
    }
    var targetLayers = $(this).parents('li').attr('rel').split(' ')
    for (var i = targetLayers.length - 1; i >= 0; i--){
      if (layers[targetLayers[i]]) { layers[targetLayers[i]].visible(this.checked) }
    }
  })
}

function bingCallback(data) {

  /* Display each resource as an image layer. */
  var resourceSets = data.resourceSets;
  for (var i = 0; i < resourceSets.length; i++) {
    var resources = data.resourceSets[i].resources;
    for (var j = 0; j < resources.length; j++) {
      var resource = resources[j];
      window.satLyr = po.image()
        .url(Polymaps.bingUrlTemplate(resource.imageUrl, resource.imageUrlSubdomains))
        .id('satellite')
        .visible(false)
      map.add(satLyr).tileSize({x: resource.imageWidth, y: resource.imageHeight});
    }
  }

  /* Display copyright notice. */
  $('#copyright').append(
    $('<span id="satlyr_attribution"></span>').append("Base layer: " + data.copyright).hide()
  )
  loadLayers()
  bindControls()
  if (!window.mapLyr) {
    $('#basemap_sat').click()
  }
}

function bindControls() {
  $('#basemap_map').click(function() {
    window.mapLyr.visible(true)
    window.satLyr.visible(false)
    $('#maplyr_attribution').show()
    $('#satlyr_attribution').hide()
  })
  $('#basemap_sat').click(function() {
    if (typeof(mapLyr) != 'undefined') mapLyr.visible(false)
    window.satLyr.visible(true)
    $('#maplyr_attribution').hide()
    $('#satlyr_attribution').show()
  })
}

function toggleLegend() {
  if ($('#legendcontent:visible').length > 0) {
    $('#legend').addClass('collapsed').removeClass('expanded')
    collapseLegend()
  } else {
    $('#legend').removeClass('collapsed').addClass('expanded')
    expandLegend()
  }
}

function collapseLegend() {
  $('#togglecollapse').removeClass('ui-icon-arrow-1-sw').addClass('ui-icon-arrow-1-ne')
  $('#legendcontent').animate({height: 0}).animate({width: 0}, function() {
    $('#legendcontent').hide()
  })
}

function expandLegend() {
  $('#togglecollapse').addClass('ui-icon-arrow-1-sw').removeClass('ui-icon-arrow-1-ne')
  $lc = $('#legendcontent')
  $lc.css({display:'block', width:'auto', height:'auto'})
  var w = Math.max($lc.data('originalWidth'), $lc.prop('scrollWidth')),
      h = Math.max($lc.data('originalHeight'), $lc.prop('scrollHeight'))
  $lc.animate({height: h+'px', width:  w+'px'})
}
