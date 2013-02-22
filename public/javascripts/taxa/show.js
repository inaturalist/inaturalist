$(document).ready(function(){
  $('#tabs').tabs()
  
  $('#taxon_range_map').taxonMap()
  window.map = $('#taxon_range_map').data('taxonMap')
  $('#tabs').bind('tabsshow', function(event, ui) {
    if (ui.panel.id == "taxon_range") {
      google.maps.event.trigger(window.map, 'resize')
      $('#taxon_range_map').taxonMap('fit')
    }
  })
  
  $('.list_selector_row .addlink')
    .bind('ajax:beforeSend', function() {
      $(this).hide()
      $(this).nextAll('.loading').show()
    })
    .bind('ajax:complete', function() {
      $(this).nextAll('.loading').hide()
    })
    .bind('ajax:success', function() {
      $(this).siblings('.removelink').show()
      $(this).parents('.list_selector_row').addClass('added')
    })
    .bind('ajax:error', function(event, jqXHR, ajaxSettings, thrownError) {
      $(this).show()
      var json = eval('(' + jqXHR.responseText + ')')
      var errorStr = 'Heads up: ' + json.errors
      alert(errorStr)
    })
    
  $('.list_selector_row .removelink')
    .bind('ajax:beforeSend', function() {
      $(this).hide()
      $(this).nextAll('.loading').show()
    })
    .bind('ajax:complete', function() {
      $(this).nextAll('.loading').hide()
    })
    .bind('ajax:success', function() {
      $(this).siblings('.addlink').show()
      $(this).parents('.list_selector_row').removeClass('added')
    })
    .bind('ajax:error', function(event, jqXHR, ajaxSettings, thrownError) {
      $(this).show()
    })

  if (TAXON.auto_description) {
    getDescription('/taxa/'+TAXON.id+'/description')
  }
})

function getDescription(url) {
  $.ajax({
    url: url,
    method: 'get',
    beforeSend: function() {
      $('.taxon_description').loadingShades()
    },
    success: function(data, status) {
      $('.taxon_description').replaceWith(data);
      $('.taxon_description select').change(function() {
        getDescription('/taxa/'+TAXON.id+'/description?from='+$(this).val())
      })
    },
    error: function(request, status, error) {
      $('.taxon_description').loadingShades('close')
    }
  })
}