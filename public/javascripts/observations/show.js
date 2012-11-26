$(document).ready(function() {
  // setup the map if one is needed
  window.observation = OBSERVATION;
  if ((observation.latitude && observation.longitude) || (observation.private_latitude && observation.private_longitude)) {
    window.map = iNaturalist.Map.createMap({
      lat: 40.714, 
      lng: -98.262, 
      zoom: observation.map_scale || 3, 
      controls: 'small'
    });
    map.addObservation(observation, {clickable: false, showAccuracy: true});
    var center = new google.maps.LatLng(
      observation.private_latitude || observation.latitude, 
      observation.private_longitude || observation.longitude);
    map.setCenter(center);
    google.maps.event.addListenerOnce(map, 'idle', function() {
      if (observation._circle) {
        map.fitBounds(map.getBounds().union(observation._circle.getBounds()))
      }
      google.maps.event.trigger(map, 'zoom_changed')
    })
    
    $(window).load(function() {
      var newWidth = $('#where-and-photos').width() - $("#photos").width()
      newWidth -= 11;
      var newHeight = $('#photos .first img').height()
      $('#where').width(newWidth)
      $('#map').width(newWidth)
      if (newHeight) {
        $('#map').height(newHeight)
      }
      if (map && observation) {
        google.maps.event.trigger(map, 'resize')
        map.setCenter(center)
      }
    })
  }
  
  $('.identification_form_wrapper input.text').simpleTaxonSelector({
    buttonText: 'Find',
    afterSelect: function(wrapper) {
      var button = $(wrapper).parents('.identification_form_wrapper').find('.default.button');
      $(button).removeClass('disabled').attr('disabled', null);
      $(button).focus();
    },
    afterUnselect: function(wrapper) {
      var button = $(wrapper).parents('.identification_form_wrapper').find('.default.button');
      $(button).addClass('disabled').attr('disabled', 'disabled');
    }
  });

  // Disable the submit button by default
  $('.identification_form_wrapper .default.button').addClass('disabled').attr('disabled', 'disabled');
  $('#new_identification_form .default.button').addClass('disabled').attr('disabled', 'disabled');
  
  $('#new_identification_form .species_guess').simpleTaxonSelector({
    buttonText: 'Find',
    afterSelect: function(wrapper) {
      var button = $('#new_identification_form').find('.default.button');
      $(button).removeClass('disabled').attr('disabled', null);
    },
    afterUnselect: function(wrapper) {
      var button = $('#new_identification_form').find('.default.button');
      $(button).addClass('disabled').attr('disabled', 'disabled');
    }
  });
  
  $('#forms').tabs();
  
  $('.quality_assessment .quality_metric_vote_link').live('click', function(e) {
    e.preventDefault()
    var tr = $(this).parents('tr.quality_metric')
    $.ajax({
      url: $(this).attr('href'),
      dataType: 'json',
      type: $(this).attr('data-http-method'),
      data: {authenticity_token: $('meta[name=csrf-token]').attr('content')},
      success: function(data, status) {
        if (data.error) {
          alert(data.error)
        } else if (data.html) {
          tr.replaceWith(data.html)
        }
      }
    })
  })
  
  $('a[rel=alternate]').each(function() {
    $(this).css({
      background: "url(http://www.google.com/s2/u/0/favicons?domain=" + this.hostname + ") left center no-repeat",
      "padding": "1px 0 1px 20px"
    })
  })
  
  $('#added_to_id_please .button')
    .bind('ajax:before', function() {
      $('#added_to_id_please').fadeOut(function() {$('#need_id_help').fadeIn()})
    })
    
  $('#need_id_help .button')
    .bind('ajax:before', function() {
      $('#need_id_help').fadeOut(function() {$('#added_to_id_please').fadeIn()})
    })

  $('#project_menu .addlink').bind('ajax:before', function() {
    var loading = $('<div>&nbsp;</div>').addClass('loadingclick inter')
    loading.width($(this).width())
    loading.height($(this).height())
    loading.css({backgroundPosition: 'center center'})
    $(this).hide()
    $(this).after(loading)
  }).bind('ajax:success', function(e, json, status) {
    $(this).siblings('.loadingclick').remove()
    $('#removelink_project_'+json.project_id).show()
    if (json.project && json.project.project_observation_fields && json.project.project_observation_fields.length > 0) {
      showObservationFieldsDialog({
        url: '/observations/'+window.observation.id+'/fields?project_id='+json.project_id,
        title: 'Project observation fields for ' + json.project.title
      })
    }
  }).bind('ajax:error', function(e, xhr, error, status) {
    $(this).siblings('.loadingclick').remove()
    $(this).show()
    var json = $.parseJSON(xhr.responseText)
    if (json.error.match(/observation field/)) {
      showObservationFieldsDialog({
        url: '/observations/'+window.observation.id+'/fields?project_id='+$(this).data('project-id'),
        title: 'Project observation fields'
      })
    } else {
      alert(json.error)
    }
  })
  $('#project_menu .removelink').bind('ajax:before', function() {
    var loading = $('<div>&nbsp;</div>').addClass('loadingclick inter')
    loading.width($(this).width())
    loading.height($(this).height())
    loading.css({backgroundPosition: 'center center'})
    $(this).hide()
    $(this).after(loading)
  }).bind('ajax:success', function(e, json, status) {
    $(this).siblings('.loadingclick').remove()
    $('#addlink_project_'+json.project_id).show()
  }).bind('ajax:error', function(e, xhr, error, status) {
    alert(xhr.responseText)
  })

  $('.identification').each(function() {
    var taxonId = $(this).data('taxon-id')
    if (!taxonId) return
    var tipOptions = $.extend(true, {}, QTIP_DEFAULTS, {
      position: {
        my: 'right center',
        at: 'left center',
        target: 'event'
      },
      style: {
        width: 500
      },
      show: {delay: 1000, solo: true},
      hide: {event: 'mouseleave unfocus', delay: 500},
      content: {
        text: '<span class="loading status">Loading...</span>',
        ajax: {
          url: '/taxa/'+taxonId+'/tip',
          type: 'GET',
          data: {observation_id: observation.id}
        }
      }
    })
  $(this).qtip(tipOptions)
  })

})

function showObservationFieldsDialog(options) {
  options = options || {}
  var url = options.url || '/observations/'+window.observation.id+'/fields',
      title = options.title || 'Observation fields'
  var dialog = $('<div></div>').addClass('dialog').html('<div class="loading status">Loading...</div>')
  dialog.load(url, function() {
    $(this).observationFieldsForm()
    $(this).centerDialog()
    $('form:has(input[required])', this).submit(checkFormForRequiredFields)
  })
  dialog.dialog({
    modal: true,
    title: title,
    width: 600,
    minHeight: 400
  })
}

$('#add_more_photos_link').live('click', function() {
  var dialogId = "add_more_photos_dialog",
      dialog = $('#'+dialogId)
  if (dialog.length == 0) {
    dialog = $('<div></div>').addClass('dialog').html('<div class="loading status">Loading...</div>')
    dialog.attr('id', dialogId)
    dialog.load('/observations/'+window.observation.id+'/edit?partial=add_photos', function() {
      // photo selector
      var authenticity_token = $('meta[name=csrf-token]').attr('content')
      var index = window.location.href.match(/\/observations\/(\d+)/)[1]
      // The photo_fields endpoint needs to know the auth token and the index
      // for the field
      var options = {
        urlParams: {
          authenticity_token: authenticity_token,
          index: index,
          limit: 18,
          synclink_base: window.location.href
        },
        sources: PHOTO_SOURCES,
        defaultSource: DEFAULT_PHOTO_SOURCE,
        afterQueryPhotos: function() {
          if (!$(dialog).hasClass('dialogcentered')) {
            $(dialog).centerDialog()
            $(dialog).addClass('dialogcentered')
          }
        }
      }
      $('.observation_photos', this).photoSelector(options)
    })
    dialog.dialog({
      modal: true,
      title: 'Add photos to this observation',
      width: 760,
      minHeight: 300
    })
  } else {
    $(dialog).dialog('open')
  }
  return false
})
