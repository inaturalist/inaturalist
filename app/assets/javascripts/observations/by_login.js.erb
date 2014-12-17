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
