$(document).ready(function(){
  $('#tabs').tabs()
  $('.observationcontrols').observationControls({
    div: $('#taxon_observations .observations')
  })
  $('#photos').imagesLoaded(function() {
    
    var h = $(this).height() - 108
    if (h > $('#observations').height()) {
      $('#observations').css({'max-height': 'none'})
      $('#observations').height(h)
    }
  })
  
  $('#taxon_range_map').taxonMap()
  window.map = $('#taxon_range_map').data('taxonMap')
  if (ADDITIONAL_RANGES && ADDITIONAL_RANGES.length > 0) {
    $.each(ADDITIONAL_RANGES, function() {
      var range = this,
          lyr = new google.maps.KmlLayer(range.kml_url, {suppressInfoWindows: true, preserveViewport: true})

      if (range.source && range.source.in_text) {
        var title = I18n.t('range_from') + range.source.in_text,
            description = range.description || range.source.citation
      } else {
        var title = I18n.t('additional_range'),
            description = range.description || I18n.t('additional_range_data_from_an_unknown_source')
      }
      map.addOverlay(title, lyr, {
        id: 'taxon_range-'+range.id, 
        hidden: true,
        description: description
      })
    })
  }
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

  // Set up photo modal dialog
  $('#edit_photos_dialog').dialog({
    modal: true, 
    title: I18n.t('choose_photos_for_this_taxon'),
    autoOpen: false,
    width: 700,
    open: function( event, ui ) {
      $('#edit_photos_dialog').loadingShades('Loading...', {cssClass: 'smallloading'})
      $('#edit_photos_dialog').load('/taxa/'+TAXON.id+'/edit_photos', function() {
        var photoSelectorOptions = {
          defaultQuery: TAXON.name,
          skipLocal: true,
          baseURL: '/flickr/photo_fields',
          urlParams: {
            authenticity_token: $('meta[name=csrf-token]').attr('content'),
            limit: 14
          },
          afterQueryPhotos: function(q, wrapper, options) {
            $(wrapper).imagesLoaded(function() {
              $('#edit_photos_dialog').centerDialog()
            })
          }
        }
        $('.tabs', this).tabs({
          show: function(event, ui) {
            if ($(ui.panel).attr('id') == 'flickr_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(photoSelectorOptions)
            } else if ($(ui.panel).attr('id') == 'inat_obs_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(
                $.extend(true, {}, photoSelectorOptions, {baseURL: '/taxa/'+TAXON.id+'/observation_photos'})
              )
            } else if ($(ui.panel).attr('id') == 'eol_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(
                $.extend(true, {}, photoSelectorOptions, {baseURL: '/eol/photo_fields'})
              )
            } else if ($(ui.panel).attr('id') == 'wikimedia_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(
                $.extend(true, {}, photoSelectorOptions, {taxon_id: TAXON.id, baseURL: '/wikimedia_commons/photo_fields'})
              )
            }
            $(ui.panel).addClass('loaded')
            $('#edit_photos_dialog').centerDialog()
          }
        })
      })
    }
  })
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
