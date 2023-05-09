function batchEdit() {
  $('.observation .icon').toggle();
  $('#batch_edit_button').toggle();
  if ($('#batchcontrols').is(":visible")) {
    $('#batchcontrols').hide();
  } else {
    $('#batchcontrols').show();
  }
  if ($('.observation .attribute.control').length > 0) {
    $('.observation .attribute.control').toggle();
  } else {
    buildBatchEditControls();
    $('.observation').labelize();
  };

  // Uncheck all if hidden
  if ($('.observation .attribute.control:visible').length == 0) {
    $('.observation .attribute.control input:checkbox').uncheck();
  };
}

function buildBatchEditControls() {
  $('.observation').prepend(
    $('<div class="control attribute">').append(
      $('<input type="checkbox"/>')
    ).css({
      'text-align': 'center',
      'vertical-align': 'middle',
      'background-color': '#ffc',
      'position': 'relative'
    })
  );
  $('.observation').each(function() {
    var obs_id = $(this).attr('id').split('-').pop();
    $(this).find('.control input:checkbox').val(obs_id);
  });
}


function selectToday() {
  var d = new Date()
  var m = d.getMonth()+1
  var day = d.getDate()
  if (day < 10) { day = '0'+day}
  if (m < 10) { m = '0'+m }
  var dateString = [d.getFullYear(), m, day].join('-')
  $('.observed_on .date[title='+dateString+']').each(function() {
    $(this).parents('.observation').find('.control input').check()
  })
}

function redoSearchInMapArea() {
  var bounds = map.getBounds();
  $('#filters input[name=swlat]').val(bounds.getSouthWest().lat());
  $('#filters input[name=swlng]').val(bounds.getSouthWest().lng());
  $('#filters input[name=nelat]').val(bounds.getNorthEast().lat());
  $('#filters input[name=nelng]').val(bounds.getNorthEast().lng());
  $('#submit_filters_button').click();
}

function editSelected() {
  actOnSelected("/observations/edit/batch");
}

function actOnSelected(baseURL, options) {
  var options = $.extend({}, options);
  var obs_inputs = $.makeArray($('.observation .control input:checkbox:checked'));
  var obs_ids = $.map(obs_inputs, function(input) { return $(input).val(); });
  if (obs_ids.length > 0) {
    if (options.method == "post") {
      var csrfParam = $( "meta[name=csrf-param]" ).attr( "content" );
      var csrfToken = $( "meta[name=csrf-token]" ).attr( "content" );
      var form = $('<form method="post" style="display:none"></form>').attr('action', baseURL).append(
        $('<input type="hidden" name="o">').val(obs_ids.join(','))
      );
      $( "<input>" ).attr( {
        type: "hidden",
        name: csrfParam,
        value: csrfToken
      } ).appendTo( form );
      $('body').append(form);
      $(form).submit();
    } else {
      window.location = baseURL + "?o=" + obs_ids.join(',');
    }
  } else {
    alert(I18n.t('you_need_to_select_some_observations_first'));
  }
}

function flickrTagger() {
  if (!confirm(I18n.t('this_will_try_to_add_tags_to_your_flickr'))) return;

  actOnSelected(
    '/taxa/tag_flickr_photos_from_observations',
    {method: "post"}
  );
}

function deleteSelected() {
  var obs_inputs = $.makeArray($('.observation .control input:checkbox:checked'));
  var obs_ids = $.map(obs_inputs, function(input) { return $(input).val(); });
  if (obs_ids.length > 0) {
    iNaturalist.restfulDelete("/observations/delete_batch", {
      plural: true,
      data: {
        o: obs_ids.join(',')
      }, 
      complete: function() {
        $.each(obs_inputs, function() {
          $(this).parents('.observation').fadeOut('normal', function() {
            $(this).remove()
          });
        });

        $('#delete_selected_button').show();
        $('#delete_selected_button').next('.loading.status').remove();
      }
    }, $('#delete_selected_button'));
  } else {
    alert(I18n.t('you_need_to_select_some_observations_first'));
  }
}
