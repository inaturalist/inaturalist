$(document).ready(function() {
  // map
  window.map = iNaturalist.Map.createMap({
    lat: 40.714, 
    lng: -98.262, 
    zoom: 3,
    zoomControl: false
  })
  
  if (PLACE.swlat) {
    var bounds = new google.maps.LatLngBounds(
      new google.maps.LatLng(PLACE.swlat, PLACE.swlng),
      new google.maps.LatLng(PLACE.nelat, PLACE.nelng)
    )
    map.fitBounds(bounds)
  } else {
    map.setCenter(new google.maps.LatLng(PLACE.latitude, PLACE.longitude));
  }
  
  window.placeMarkers = []
  var smallIcon = new google.maps.MarkerImage('/images/mapMarkers/mm_20_stemless_DodgerBlue.png')
  smallIcon.size = new google.maps.Size(12,12)
  smallIcon.anchor = new google.maps.Point(6,6)
  function PlacesMapType(tileSize) { this.tileSize = tileSize; }
  PlacesMapType.prototype.getTile = function(coord, zoom, ownerDocument) {
    var layer = 'country_points'
    if (zoom > 4 && zoom <= 7) {
      layer = 'state_points'
    } else if (zoom > 7 && zoom <= 12) {
      layer = 'county_points'
    }
    $.getJSON(TILESTACHE_SERVER+'/'+layer+'/'+zoom+'/'+coord.x+'/'+coord.y+'.geojson', function(json) {
      for (var i = json.features.length - 1; i >= 0; i--){
        var f = json.features[i],
            place = f.properties;
        place.latitude = f.geometry.coordinates[1]
        place.longitude = f.geometry.coordinates[0]
        var marker = map.createMarker(place.latitude, place.longitude, {icon: smallIcon, title: place.display_name})
        marker.setMap(map)
        marker.placeId = place.place_id
        marker.setZIndex(1)
        google.maps.event.addListener(marker, 'click', function() {
          window.location = '/places/'+this.placeId+'?test=true'
        })
        placeMarkers.push(marker)
      }
    })
    var div = ownerDocument.createElement('DIV')
    return div
  }
  map.overlayMapTypes.insertAt(0, new PlacesMapType(new google.maps.Size(256, 256)));
  google.maps.event.addListener(map, 'zoom_changed', function() {
    var zoom = map.getZoom()
    if (zoom > 4 && zoom <= 7) {
      layer = 'state_points'
      for (var i = placeMarkers.length - 1; i >= 0; i--){
        placeMarkers[i].setVisible(placeMarkers[i].placeType == 'state')
      }
    } else if (zoom > 7 && zoom < 12) {
      for (var i = placeMarkers.length - 1; i >= 0; i--){
        placeMarkers[i].setVisible(placeMarkers[i].placeType == 'county')
      }
    } else {
      for (var i = placeMarkers.length - 1; i >= 0; i--){
        placeMarkers[i].setVisible(placeMarkers[i].placeType == 'country')
      }
    }
  })
  
  var icon = iNaturalist.Map.createPlaceIcon()
  var marker = map.createMarker(PLACE.latitude, PLACE.longitude, {
    icon: icon
  })
  marker.setMap(map)
  if (PLACE_GEOMETRY_KML_URL.length > 0) {
    var kml = new google.maps.KmlLayer(PLACE_GEOMETRY_KML_URL, {suppressInfoWindows: true})
    kml.setMap(map)
  }
  marker.setZIndex(2)
  
  // Load wikipedia desc
  $.ajax({
    url: WIKIPEDIA_DESCRIPTION_URL,
    method: 'get',
    success: function(data, status) {
      $('#wikipedia_description').html(data)
    },
    error: function(request, status, error) {
      $('#nodescription').show()
      $('#wikipedia_description .loading').hide()
    }
  })
  
  var flickrOptions = {
    api_key: FLICKR_API_KEY,
    sort: 'interestingness-desc',
    page: 1,
    per_page: 7,
    woe_id: PLACE.woeid,
    extras: 'url_t,owner_name,date_upload',
    safe_search: 1,
    text: "landscape -portrait -model",
    license: '1,2,3,4,5,6'
  }
  
  if (PLACE.swlng) {
    flickrOptions.bbox = [PLACE.swlng, PLACE.swlat, PLACE.nelng, PLACE.nelat].join(', ')
  } else {
    flickrOptions.lat = PLACE.latitude
    flickrOptions.lon = PLACE.longitude
  }
  // console.log("flickrOptions: ", flickrOptions);
  $.getJSON(
    "http://www.flickr.com/services/rest/?method=flickr.photos.search&format=json&jsoncallback=?",
    flickrOptions,
    function(json) {
      // console.log("json: ", json);
      if (json.photos && json.photos.photo) {
        for (var i = json.photos.photo.length - 1; i >= 0; i--){
          var p = json.photos.photo[i],
              date = new Date(p.dateupload * 1000),
              attribution = ("(CC) " + (date.getFullYear() || '') + " " + p.ownername).replace(/\s+/, ' ')
          $('#placephotos').append(
            $('<a href="http://www.flickr.com/photos/'+p.owner+'/'+p.id+'"></a>').append(
              $('<img></img>')
                .attr('src', p.url_t).attr('title', attribution)
            )
          )
        }
      }
    }
  );
})