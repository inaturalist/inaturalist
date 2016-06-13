$(document).ready(function() {
  $('.species_guess').taxonAutocomplete({
    idEl: $("#observation_taxon_id"),
    showPlaceholder: true,
    allowPlaceholders: true });
  $('.observed_on_string').iNatDatepicker();
  var map = iNaturalist.Map.createMap({
    div: $('#map').get(0),
    mapTypeId: google.maps.MapTypeId.HYBRID,
    bounds: BOUNDS
  })
  window.map = map;

  var preserveViewport = false
  if (typeof(PROJECT) != 'undefined' && PROJECT) {
    preserveViewport = PROJECT.latitude && PROJECT.zoom_level
    if (PROJECT.latitude) {
      map.setCenter(new google.maps.LatLng(PROJECT.latitude, PROJECT.longitude));
    }
    if (PROJECT.zoom_level) {
      map.setZoom(PROJECT.zoom_level)
    }
    if (PROJECT.map_type) {
      map.setMapTypeId(PROJECT.map_type)
    }
  }
  if (typeof(PLACE) != 'undefined' && PLACE) {
    window.map.addPlaceLayer({ place: PLACE });
    map.setPlace(PLACE, {
      preserveViewport: preserveViewport,
      click: function(e) {
        $.fn.latLonSelector.handleMapClick(e)
      }
    })
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map).div)
  } else if (typeof(KML_ASSET_URLS) != 'undefined' && KML_ASSET_URLS != null && KML_ASSET_URLS.length > 0) {
    for (var i=0; i < KML_ASSET_URLS.length; i++) {
      lyr = new google.maps.KmlLayer(KML_ASSET_URLS[i], {preserveViewport: preserveViewport, suppressInfoWindows: true})
      map.addOverlay('KML Layer', lyr)
      google.maps.event.addListener(lyr, 'click', function(e) {
        $.fn.latLonSelector.handleMapClick(e)
      })
    }
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map).div)
  }
  $('.place_guess').latLonSelector({
    mapDiv: $('#map').get(0),
    map: map
  })
  
  $('#mapcontainer').hover(function() {
    $('#mapcontainer .description').fadeOut()
  })

  $('.observation_fields_form_fields').observationFieldsForm()
  $('.observation_photos').each(function() {
    var authenticity_token = $(this).parents('form').find('input[name=authenticity_token]').val()
    if (window.location.href.match(/\/observations\/(\d+)/)) {
      var index = window.location.href.match(/\/observations\/(\d+)/)[1]
    } else {
      var index = 0
    }
    // The photo_fields endpoint needs to know the auth token and the index
    // for the field
    var options = {
      urlParams: {
        authenticity_token: authenticity_token,
        index: index,
        limit: 15,
        synclink_base: window.location.href
      }
    }
    if (DEFAULT_PHOTO_IDENTITY_URL) {
      options.baseURL = DEFAULT_PHOTO_IDENTITY_URL
    } else {
      options.defaultSource = 'local'
    }
    if (PHOTO_IDENTITY_URLS && PHOTO_IDENTITY_URLS.length > 0) {
      options.urls = PHOTO_IDENTITY_URLS
    }
    $(this).photoSelector(options)
  })

  if (SOUNDCLOUD_IDENTITY) {
    $('.observation_sounds').each(function(){
      var index = (window.location.href.match(/\/observations\/(\d+)/) || [])[1] || 0
      $(this).soundSelector({index: index});
    })
  }

  $('.ui-tabs').tabs();
  
  if ($('#accept_terms').length != 0) {
    $("input[type=submit].default").attr("exception", "true");
    $('.observationform').submit(function() {
      if (!$('input[type=checkbox]#accept_terms').is(':checked')){
        var c = confirm("You didn't agree to the project's terms, this will still save the observation " +
                      "to iNaturalist, but it won't be added to the project. Is this what you want?"
        );
        if (!c) {
          return false;
        }
      }
    })
  }

  $("#observation_description").textcompleteUsers( );
})

function afterFindPlaces() {
  TaxonBrowser.ajaxify('#find_places')
}
