$(document).ready(function() {
  window.map = new google.maps.Map(document.getElementById("map"), {
    zoom: 2,
    center: new google.maps.LatLng(0, 0),
    mapTypeId: google.maps.MapTypeId.TERRAIN
  })
  $('#controls').hide()
  $('#legend .breadcrumbs').nextAll().hide()
  $('#legend .small.meta').hide()
  $('#legend .stacked').removeClass('stacked')
  
  if (extent) {
    map.fitBounds(
      new google.maps.LatLngBounds(
        new google.maps.LatLng(extent[0]['lat'], extent[0]['lon']),
        new google.maps.LatLng(extent[1]['lat'], extent[1]['lon'])
      )
    )
  }
  
  if (taxonRangeUrl) {
    window.taxonRangeLyr = new google.maps.KmlLayer(taxonRangeKmlUrl,
        {suppressInfoWindows: true});
    taxonRangeLyr.setMap(map);
  }
  
  $.get(observationsJsonUrl, function(data) {
    map.addObservations(data)
  })
})
