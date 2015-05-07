$(document).ready(function() {
  // setup the map if one is needed
  window.observation = OBSERVATION;
  $("#map").taxonMap({ clickable: false, showAccuracy: true });
  window.map = $("#map").data("taxonMap");
  window.setMapCenter = function() {
    map.setCenter(new google.maps.LatLng(observation.private_latitude || observation.latitude, observation.private_longitude || observation.longitude));
    google.maps.event.removeListener(window.resizeListener)
  }
  if ( map ) {
    $(window).load(function() {
      var photosHeight = $('#photos .first img').height(),
          soundsHeight = $('#sounds').height() - $('#sounds .moresounds').height() - $('#sounds .meta').height(),
          mediaWidth = $('#media').width(),
          newWidth = $('#where-and-photos').width() - mediaWidth, 
          newHeight
      
      if (photosHeight && soundsHeight) { newHeight = soundsHeight + $('#photos').height() }
      else if (photosHeight) { newHeight = photosHeight }
      else if (soundsHeight) { newHeight = soundsHeight - 10 }
      if (newWidth) {
        newWidth -= 11;
        $('#where').width(newWidth);
        $('#map').width(newWidth);
      }
      if (newHeight) {
        $('#map').height(newHeight);
      }
      if (map && observation) {
        window.resizeListener = google.maps.event.addListener(map, 'resize', setMapCenter);
        google.maps.event.trigger(map, 'resize');
      }
    });
  }
  
  $('.identification_form_wrapper input.text').simpleTaxonSelector({
    buttonText: I18n.t('find'),
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
    buttonText: I18n.t('find'),
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
      background: "url(http://www.google.com/s2/favicons?domain=" + this.hostname + ") left center no-repeat",
      'background-size': '16px 16px',
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
    var projectId = $(this).data('project-id') || json.project_id
    $(this).siblings('.loadingclick').remove()
    $(this).siblings('.removelink').show()
    $(this).hide()
  }).bind('ajax:error', function(e, xhr, error, status) {
    $(this).siblings('.loadingclick').remove()
    $(this).show()
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
    $(this).siblings('.addlink').show()
    $(this).hide()
  }).bind('ajax:error', function(e, xhr, error, status) {
    // alert(xhr.responseText)
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

  $('[class*=bold-]').boldId()
})

$('#add_more_photos_link').live('click', function() {
  var dialogId = "add_more_photos_dialog",
      dialog = $('#'+dialogId)
  if (dialog.length == 0) {
    dialog = $('<div></div>').addClass('dialog').html('<div class="loading status">'+I18n.t('loading')+'</div>')
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
      title: I18n.t('add_photos_to_this_observation'),
      width: 760,
      minHeight: 300
    })
  } else {
    $(dialog).dialog('open')
  }
  return false
})

function showCommunityTaxonDialog() {
  var dialogId = "community_taxon_dialog",
      dialog = $('#'+dialogId)
  if (dialog.length == 0) {
    dialog = $('<div></div>').addClass('dialog').html('<div class="loading status">'+I18n.t('loading')+'</div>')
    dialog.attr('id', dialogId)
    dialog.load('/observations/'+window.observation.id+'/community_taxon_summary', function() {
      if (!$(dialog).hasClass('dialogcentered')) {
        $(dialog).centerDialog()
        $(dialog).addClass('dialogcentered')
      }
    })
    dialog.dialog({
      modal: true,
      title: I18n.t('about_community_taxa'),
      width: '80%',
      minHeight: 600
    })
  } else {
    $(dialog).dialog('open')
  }
  return false
}
