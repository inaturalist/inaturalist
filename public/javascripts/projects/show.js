$(document).ready(function() {
  var map = window.map = iNaturalist.Map.createMap({lat: 0, lng: 0, zoom: 3}),
      lyr, 
      kmlSet = false;
  
  for (var i=0; i < KML_ASSET_URLS.length; i++) {
    lyr = new google.maps.KmlLayer(KML_ASSET_URLS[i])
    lyr.setMap(window.map)
    kmlSet = true
  }
  
  if (PLACE_GEOMETRY_KML_URL) {
    lyr = new google.maps.KmlLayer(PLACE_GEOMETRY_KML_URL, {preserveViewport: true})
    map.addOverlay(PLACE.name + ' boundary', lyr)
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map))
  }
  
  map.addObservations(OBSERVATIONS)
  
  if (!kmlSet) {
    if (PLACE) {
      if (PLACE.swlat) {
        var bounds = new google.maps.LatLngBounds(
          new google.maps.LatLng(PLACE.swlat, PLACE.swlng),
          new google.maps.LatLng(PLACE.nelat, PLACE.nelng)
        )
        map.fitBounds(bounds)
      } else {
        map.setCenter(new google.maps.LatLng(PLACE.latitude, PLACE.longitude));
      }
    } else if (OBSERVATIONS && OBSERVATIONS.length > 0) {
      map.zoomToObservations()
    }
  }
})
