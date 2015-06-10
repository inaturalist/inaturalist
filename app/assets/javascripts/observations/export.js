var REJECT_PARAMS = ['filters_open', 'order', 'order_by', 'utf8', 'flow_task_id', 'view', 'taxon_name']
function reloadPreview() {
  $('#previewwrapper').loadingShades()
  if (window.previewRequest) {
    previewRequest.abort()
  }
  window.previewRequest = $.ajax({
    url: '/observations',
    data: $('#query').val()+'&partial=cached_component',
    type: 'GET',
  }).success(function(html, status, req) {
    $('#preview .observations .content').html(html)
    $('#previewwrapper').loadingShades('close')
    var total = parseInt(req.getResponseHeader('X-Total-Entries')),
        page = parseInt(req.getResponseHeader('X-Page')),
        perPage = parseInt(req.getResponseHeader('X-Per-Page')),
        start = page * perPage - perPage
    $('#previewheader .status').text((start+1) + ' - ' + (Math.min(start+perPage, total)) + ' of ' + total)
  })
}
function cleanQuery(q) {
  var params = $.deparam(q), newParams = {}
  $.each(params, function(k,v) {
    if (v.length == 0 || (v.length == 1 && v[0] == '')) {
      if (k.match(/^field:/)) {
        newParams[k] = v
      } else {
        return
      }
    }
    if (v.length !== 0 && v.length != 0 && REJECT_PARAMS.indexOf(k) < 0) {
      newParams[k] = v
    }
  })
  return $.param(newParams)
}
function queryChanged() {
  var input = $('#query'),
      v = input.val(), 
      project_id = null, 
      login = null
  if (v.match(/observations\/project/)) {
    project_id = v.match(/observations\/project\/([^\?\/]+)/)[1]
  } else if (v.match(/observations\/\w+/)) {
    login = v.match(/observations\/([^\?\/]+)/)[1]
  }
  if (v.match(/\//)) {
    v = v.split('?')[1] || ''
  } 
  if (project_id) {v += '&projects[]='+project_id}
  if (login) {v += '&user_id='+login}
  var query = cleanQuery(v)
  input.val(query)
  setFiltersFromQuery(query)
  reloadPreview()
}
function filtersToQuery() {
  var query = $('#filters :input').serialize()
  $('#query').val(cleanQuery(query))
}
$(document).ready(function() {
  showFilters()
  $('#query').change(queryChanged)
  $('#filters :input').change(function() {
    filtersToQuery()
    reloadPreview()
  })
  $('#filtersplaceholder').outerHeight($('#filters').outerHeight())
  $('#filters').css({position: 'absolute', top: $('#filtersplaceholder').offset().top})
  var initQuery = cleanQuery($.param($.deparam.querystring()))
  if (initQuery.length > 0) {
    console.log('DEBUG: initQuery: ', initQuery)
    $('#query').val(initQuery)
    setFiltersFromQuery(initQuery)
    filtersToQuery()
    reloadPreview()
  }
  $('#new_observations_export_flow_task').bind('ajax:success', function(e, json) {
    window.flowTask = json
    var runUrl = '/flow_tasks/'+json.id+'/run.json'
    runFlowTask(runUrl)
    $('#rundialog').dialog({
      modal: true, 
      title: I18n.t('exporting'),
      width: 490
    })
    $('#exportingstatus').removeClass('notice box centered').addClass('loading').html(I18n.t('loading'))
    $('#receive_an_email .inter, #receive_an_email .status').remove()
    $('#receive_an_email .button').show()
  })
  $('#new_observations_export_flow_task').bind('ajax:error', function(e,r) {
    var json = $.parseJSON(r.responseText)
    alert(json.error)
  })
})
window.runFlowTask = function(runUrl) {
  window.delayedLinkTries = (window.delayedLinkTries || 0) + 1
  if (window.delayedLinkTries > 20) {
    $('#exportingstatus').removeClass('loading').addClass('notice box centered').html(I18n.t('views.observations.export.taking_a_while'))
    return
  }
  $.ajax({
    url: runUrl,
    type: 'get',
    dataType: 'json',
    statusCode: {
      // Accepted: request acnkowledged but file hasn't been generated
      202: function() {
        setTimeout('runFlowTask("'+runUrl+'")', 5000)
      },
      // OK: file is ready
      200: function(flowTask) {
        var redirectUrl = flowTask.redirect_url
        if (redirectUrl.match(/\?/)) { redirectUrl += '&flow_task_id='+flowTask.id }
        else { redirectUrl += '?flow_task_id='+flowTask.id }
        window.open(redirectUrl, '_self')
      }
    }
  }).error(function() {
    alert("Something went wrong.")
  })
}
function emailWhenComplete() {
  $('#receive_an_email .button').hide()
  $('#receive_an_email').append("<span class='loading status'>"+I18n.t('saving')+"</span>")
  $.post('/observations/email_export/'+window.flowTask.id, function() {
    $('#receive_an_email .status').remove()
    $('#receive_an_email').append("<span class='inter'>"+I18n.t('views.observations.export.well_email_you')+"</span>")
  })
}
