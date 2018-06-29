$('.tile .img').imagesLoaded(function() {
  $('img', this).not('.iconic').centerInContainer()
})
$('.clearbtn').click(function() {
  $(this).siblings(':input').val(null)
})
$('.taxonmap').waypoint(function() {
  if ($(this).data('taxonMap')) return
  $(this).taxonMap()
}, {
  triggerOnce: true,
  offset: '100%'
} );
$('#printbtn').click(function() {
  var layout = $('#print_dialog input[name*=layout]:checked').val(),
      printUrl = window.location.toString();
  if ( printUrl.indexOf( "?" ) >= 0 ) {
    printUrl += "&print=t";
  } else {
    printUrl += "?print=t";
  }
  printUrl += "&layout="+layout;
  var w = window.open(printUrl, '_blank')
  return false
})
