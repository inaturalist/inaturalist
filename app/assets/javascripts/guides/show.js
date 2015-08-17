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
})
$('#new_guide_pdf_flow_task input[type=submit]').click(function() {
  if ($('#guide_pdf_flow_task_options_query_all:checked').length > 0) {
    checkForExistingDefaultPdf()
  } else {
    createFlowTask()
  }
  return false
})
function checkForExistingDefaultPdf() {
  var layout = $('#new_guide_pdf_flow_task input[name*=layout]:checked').val(),
      pdfUrl = '/guides/'+GUIDE.id+'.'+layout+'.pdf'
  // send HEAD request to see if PDF exists
  $.ajax({
    type: 'HEAD',
    url: pdfUrl,
    statusCode: {
      200: function() {
        // if exists, open that in new window and cancel form submission
        window.open(pdfUrl, '_self')
      },
      404: function() {
        // else submit the form
        createFlowTask()
      }
    }
  })
}
function createFlowTask() {
  loadingClickForButton.apply($('.modal:visible input[data-loading-click]').get(0), [{ajax:false}])
  $('.modal:visible .patience').show()
  $('#new_guide_pdf_flow_task').submit()
}
$('#printbtn').click(function() {
  var layout = $('#new_guide_pdf_flow_task input[name*=layout]:checked').val(),
      printUrl = window.location.pathname.replace(/\.+/, '') + '.' + layout+'.pdf'
  if ($('#guide_pdf_flow_task_options_query_all:checked').length == 0) {
    if (window.location.search.length == 0) { printUrl += "?print=t" }
    else { printUrl += window.location.search + '&print=t' }
  } else {
    printUrl = printUrl.replace(/\.pdf\??.*$/, '.pdf?print=t')
  }
  var w = window.open(printUrl, '_blank')
  return false
})
$('#new_guide_pdf_flow_task').bind('ajax:success', function(e, json) {
  // on form submit success, hit flow_tasks/run and wait until flow task is complete
  var runUrl = '/flow_tasks/'+json.id+'/run.json',
      pdfUrl = '/guides/'+GUIDE.id
  runFlowTask(runUrl, pdfUrl)
  // open url in new window when complete and close modal
})
window.runFlowTask = function(runUrl, pdfUrl) {
  window.delayedLinkTries = (window.delayedLinkTries || 0) + 1
  if (window.delayedLinkTries > 20) {
    $('.modal:visible .patience').hide()
    var btn = $('.modal.visible input[data-loading-click]')
    btn.attr('disabled', false).removeClass('disabled description')
    btn.val(btn.data('original-value'))
    alert('This seems to be taking forever.  Please try again later.')
    return
  }
  $.ajax({
    url: runUrl,
    type: 'get',
    dataType: 'json',
    statusCode: {
      // Accepted: request acnkowledged but file hasn't been generated
      202: function() {
        setTimeout('runFlowTask("'+runUrl+'", "'+pdfUrl+'")', 5000)
      },
      // OK: file is ready
      200: function(flowTask) {
        $('.modal:visible .patience').hide()
        var btn = $('.modal.visible input[data-loading-click]')
        btn.attr('disabled', false).removeClass('disabled description')
        btn.val(btn.data('original-value'))
        var redirectUrl = flowTask.redirect_url
        if (redirectUrl.match(/\?/)) { redirectUrl += '&flow_task_id='+flowTask.id }
        else { redirectUrl += '?flow_task_id='+flowTask.id }
        window.open(redirectUrl, '_self')
      }
    }
  }).error(function(arguments) {
    // console.log("[DEBUG] error: ", arguments)
  })
}
