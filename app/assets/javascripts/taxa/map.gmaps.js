$(document).ready(function() {
  window.map = new google.maps.Map(document.getElementById("map"), {
    zoom: 2,
    center: new google.maps.LatLng(0, 0),
    mapTypeId: google.maps.MapTypeId.TERRAIN
  })
  $('#controls').hide()
  $('#legendcontent').hide()
  $('#legend .stacked').removeClass('stacked')
  $('#legendfooter .last').html(
    '<div class="meta">FYI, this map is a lot cooler in modern browsers like ' +
    '<a href="http://www.apple.com/safari/">Safari</a>, ' +
    '<a href="http://www.google.com/chrome">Chrome</a>, and ' +
    '<a href="http://www.mozilla.org/en-US/firefox/">Firefox</a>.</div>')
  
  if (extent) {
    map.fitBounds(
      new google.maps.LatLngBounds(
        new google.maps.LatLng(extent[0]['lat'], extent[0]['lon']),
        new google.maps.LatLng(extent[1]['lat'], extent[1]['lon'])
      )
    )
  }
  
  if (taxonRangeUrl) {
    taxonRangeLyr = new google.maps.KmlLayer(taxonRangeKmlUrl,
        {suppressInfoWindows: true});
    map.addOverlay(taxonRangeLyr)
    map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map).div)
  }
  
  $.get(observationsJsonUrl, function(data) {
    map.addObservations(data)
  })
})
