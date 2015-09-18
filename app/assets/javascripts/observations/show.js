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

  $('#new_identification_form .species_guess').taxonAutocomplete({
    taxon_id_el: $("input.ac_hidden_taxon_id"),
    extra_class: "identification",
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
  
  $('#data_quality_assessment').on('click', '.quality_metric_vote_link', function(e) {
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

  var qtip = $('#add-to-project-button').qtip('api');
  if( qtip ) {
    qtip.set({
      events: {
        render: function(event, api) {
          $('#projectschooser .addlink').bind('ajax:before', function() {
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
            // eror handling is done in observation_fields.js
          })
          $('#projectschooser .removelink').bind('ajax:before', function() {
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
        }
      }
    });
  }

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

  $('#sharebutton').qtip($.extend(true, {}, QTIP_DEFAULTS, {
    content: {
      text: $('#sharing')
    },
    position: {
      my: 'top center',
      at: 'bottom center',
      target: $('#sharebutton')
    },
    show: {event: 'click'},
    hide: {event: 'click unfocus'}
  }))
  $('#sharing').hide()
  $('.favebutton').bind('ajax:before', function() {
    $(this).hide()
    $(this).siblings('.favebutton').show()
  })
  $('#favebutton').bind('ajax:before', function() {
    var s = $('#fave .votes_for_button').html()
    if (!s) { return }
    var count = parseInt(s.match(/(\d+)\s/)[1]) + 1
    $('#fave .votes_for_button').html(I18n.t('x_faves', {count: count}))
  })
  $('#unfavebutton').bind('ajax:before', function() {
    var s = $('#fave .votes_for_button').html()
    if (!s) { return }
    var count = parseInt(s.match(/(\d+)\s/)[1]) - 1
    $('#fave .votes_for_button').html(I18n.t('x_faves', {count: count}))
  })
  $('.votes_for_button').qtip($.extend(true, {}, QTIP_DEFAULTS, {
    content: {
      text: function(event, api) {
        $.ajax({ url: '/votes/for/observation/'+OBSERVATION.id })
            .done(function(html) {
                api.set('content.text', html)
            })
            .fail(function(xhr, status, error) {
                api.set('content.text', status + ': ' + error)
            })
        return '<span class="loading status">' + I18n.t('loading') + '</span>';
      }
    },
    show: {event: 'click'},
    hide: {event: 'click unfocus'},
    style: {
      classes: 'ui-tooltip-light ui-tooltip-shadow votes_for_tip tools-dropdown'
    },
    position: {
      my: 'top center',
      at: 'bottom center',
      target: $('#fave')
    }
  }));
  // toggle users' reviewed status for observations
  $( "#reviewbutton" ).bind( "ajax:before", function( ) {
    // each click sets the opposite value for reviewed
    var currentReviewState = !$(this).data( "reviewed" );
    $(this).data( "reviewed", currentReviewState );
    // set the new label
    if( currentReviewState === true ) { $(this).text( $(this).data( "unreview-label" ) ); }
    else { $(this).text( $(this).data( "review-label" ) ); }
    // update the link to allow toggling reviewed back and forth
    $(this).attr( "href", $(this).attr( "href" ).
      replace( /reviewed=.*$/, "reviewed=" +  currentReviewState ));
  });

  $(document).bind('keyup', 'i', window.showIdentificationForm);
  $(document).bind('keyup', 'f', function() {
    $('.favebutton:visible').click()
  });
  $(document).bind('keyup', 'c', function() {
    $('#new-comment-form-tab').click()
    $('#comment_body').focus()
  });

  $('#comment_body').textcompleteUsers( );
  $('#identification_body').textcompleteUsers( );
})

$(document).on('click', '#add_more_photos_link', function() {
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

$(document).on('click', '.joinlink', function(e) {
  $(this).parents('.qtip').qtip('hide')
  var dialogId = "join_project_modal",
      dialog = $('#'+dialogId),
      projectId = $(this).data('project-id')
  if (dialog.length == 0) {
    dialog = $('<div></div>').addClass('dialog').html('<div class="loading status">'+I18n.t('loading')+'</div>')
    dialog.attr('id', dialogId)
    dialog.load('/projects/'+projectId+'/join?partial=join')
    dialog.dialog({
      modal: true,
      title: I18n.t('join_project'),
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

function showLocationDetails(link, options) {
  var options = options || {},
      user_id = options.user_id
  if (options.user_id) {
    $.post('/users/'+user_id, {'_method': 'PUT', 'user[prefers_location_details]': true}, null, 'json')
  }
  $('#location_details').slideDown()
  $(link).hide()
  $(link).siblings().show()
}
function hideLocationDetails(link, options) {
  var options = options || {},
      user_id = options.user_id
  if (options.user_id) {
    $.post('/users/'+user_id, {'_method': 'PUT', 'user[prefers_location_details]': false}, null, 'json')
  }
  $('#location_details').slideUp()
  $(link).hide()
  $(link).siblings().show()
}

function showIdentificationForm() {
  $('#new-identification-form-tab').click()
  $('#new_identification input:visible:first').focus()
}
