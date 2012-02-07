window.map = iNaturalist.Map.createMap({
  lat: 40.714, 
  lng: -98.262, 
  zoom: 3,
  minZoom: 2,
  zoomControl: false
})

map.setPlace(PLACE, {kml: PLACE_GEOMETRY_KML_URL})

var placesMapType = iNaturalist.Map.builtPlacesMapType(map, {tilestacheServer: TILESTACHE_SERVER})
map.overlayMapTypes.insertAt(0, new placesMapType(new google.maps.Size(256, 256)));

var icon = new google.maps.MarkerImage('/images/mapMarkers/mm_20_stemless_GoldenRod.png')
icon.size = new google.maps.Size(12,12)
icon.anchor = new google.maps.Point(6,6)
var marker = map.createMarker(PLACE.latitude, PLACE.longitude, {
  icon: icon
})
marker.setMap(map)
marker.setZIndex(2)
