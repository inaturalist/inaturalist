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
      printUrl = window.location.pathname.replace(/\.+/, '') + '.' + layout+'.pdf'
  if ($('#print_dialog_options_query_all:checked').length == 0) {
    if (window.location.search.length == 0) { printUrl += "?print=t" }
    else { printUrl += window.location.search + '&print=t' }
  } else {
    printUrl = printUrl.replace(/\.pdf\??.*$/, '.pdf?print=t')
  }
  var w = window.open(printUrl, '_blank')
  return false
})
