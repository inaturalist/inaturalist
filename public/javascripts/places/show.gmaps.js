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

var placesMapType = iNaturalist.Map.builtPlacesMapType(map, {tilestacheServer: TILESTACHE_SERVER})
map.overlayMapTypes.insertAt(0, new placesMapType(new google.maps.Size(256, 256)));

var icon = new google.maps.MarkerImage('/images/mapMarkers/mm_20_stemless_GoldenRod.png')
icon.size = new google.maps.Size(12,12)
icon.anchor = new google.maps.Point(6,6)
var marker = map.createMarker(PLACE.latitude, PLACE.longitude, {
  icon: icon
})
marker.setMap(map)
if (PLACE_GEOMETRY_KML_URL.length > 0) {
  var kml = new google.maps.KmlLayer(PLACE_GEOMETRY_KML_URL, {suppressInfoWindows: true})
  kml.setMap(map)
}
marker.setZIndex(2)
