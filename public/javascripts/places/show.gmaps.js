function layerForZoom(zoom) {
  var layer = 'country_points_5'
  if (zoom > 3 && zoom <= 5) {
    layer = 'place_points_5'
  } else if (zoom > 5 && zoom <= 7) {
    layer = 'place_points_r0'
  } else if (zoom > 7 && zoom <= 9) {
    layer = 'place_points_r1'
  } else if (zoom > 9) {
    layer = 'place_points_r2'
  }
  return layer  
}

// map
window.map = iNaturalist.Map.createMap({
  lat: 40.714, 
  lng: -98.262, 
  zoom: 3,
  minZoom: 2,
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
window.urlsRequested = {}
var smallIcon = new google.maps.MarkerImage('/images/mapMarkers/mm_20_stemless_DodgerBlue.png')
smallIcon.size = new google.maps.Size(12,12)
smallIcon.anchor = new google.maps.Point(6,6)
var openSpaceIcon = new google.maps.MarkerImage('/images/mapMarkers/mm_20_stemless_iNatGreen.png')
openSpaceIcon.size = new google.maps.Size(12,12)
openSpaceIcon.anchor = new google.maps.Point(6,6)
function PlacesMapType(tileSize) { this.tileSize = tileSize; }
PlacesMapType.prototype.getTile = function(coord, zoom, ownerDocument) {
  var tileSize = this.tileSize,
      coordX = coord.x,
      coordY = coord.y,
      layer = layerForZoom(zoom)
      
  var div = ownerDocument.createElement('DIV')
  
  var url = TILESTACHE_SERVER+'/'+layer+'/'+zoom+'/'+coord.x+'/'+coord.y+'.geojson'
  if (urlsRequested[url]) {
    return div
  }
  urlsRequested[url] = true
  
  $.getJSON(url, function(json) {
    for (var i = json.features.length - 1; i >= 0; i--){
      var f = json.features[i],
          place = f.properties,
          proj = map.getProjection()
      place.latitude = f.geometry.coordinates[1]
      place.longitude = f.geometry.coordinates[0]
      var pt = proj.fromLatLngToPoint(new google.maps.LatLng(place.latitude, place.longitude))
      var marker = map.createMarker(place.latitude, place.longitude, {
        icon: place.place_type == 100 ? openSpaceIcon : smallIcon, 
        title: place.display_name
      })
      marker.setMap(map)
      marker.placeId = place.id
      marker.layer = layer
      marker.setZIndex(1)
      google.maps.event.addListener(marker, 'click', function() {
        window.location = '/places/'+this.placeId+'?test=true'
      })
      placeMarkers.push(marker)
    }
  })
  return div
}
map.overlayMapTypes.insertAt(0, new PlacesMapType(new google.maps.Size(256, 256)));

google.maps.event.addListener(map, 'zoom_changed', function() {
  var zoom = map.getZoom(),
      layer = layerForZoom(zoom)
  for (var i = placeMarkers.length - 1; i >= 0; i--){
    placeMarkers[i].setVisible(placeMarkers[i].layer == layer)
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
