$('#addtaxa').modal({
  backdrop: true,
  show: false
}).on('hidden', completeAddTaxa)
$('#addtaxa').on('shown.bs.modal', function() { $('input:visible:first', this).focus() })
$('#addtaxa-place .taxonchooser').chooser({
  collectionUrl: '/taxa/autocomplete.json',
  resourceUrl: '/taxa/{{id}}.json?partial=chooser'
})
$('#addtaxa-place .placechooser').chooser({
  collectionUrl: '/places/autocomplete.json',
  resourceUrl: '/places/{{id}}.json?partial=autocomplete_item',
  afterSelect: function() {
    $('#addtaxa-place .taxonchooser').nextAll(':input:visible:first').focus()
  }
})
$('#addtaxa-place .chooser, #addtaxa-place :input[name=rank]').change(function() {
  $('#addtaxa-place .status').addClass('loading').html('Counting matches...')
  if (window.matchingTaxaRequest) {
    window.matchingTaxaRequest.abort()
  }
  var params = "place_id=" + $('#addtaxa-place .placechooser').val() + 
                "&taxon_id=" + $('#addtaxa-place .taxonchooser').val()
  var rank = $('#addtaxa-place :input[name=rank]').val()
  if (rank) {
    params += "&rank="+rank
  }
  window.matchingTaxaRequest = $.getJSON('/taxa.json', params, function(taxa, status, xhr) {
    var c = parseInt(xhr.getResponseHeader('x-total-entries') || 0),
        names = $.map(taxa, function(t) { return t.name }),
        msg = I18n.t('x_matching_taxa_html', {count: c})
    if (names.length == 1) {
      msg += ": " + names.join(', ')
    } else if (names.length > 0){
      msg += ", "+ I18n.t('including') + " " + names.slice(0,10).join(', ')
    }
    $('#addtaxa-place .status').removeClass('loading').html(msg)
  })
})
window.addTaxonField = function() {
  var newInput = $('<input type="text" name="taxon_id" placeholder="'+I18n.t('start_typing_taxon_name')+'"/>')
  $('#addtaxa-single').append(newInput)
  newInput.chooser({
    collectionUrl: '/taxa/autocomplete.json',
    resourceUrl: '/taxa/{{id}}.json?partial=chooser',
    afterSelect: function(taxon) {
      window.addTaxonField()
    }
  })
  $('#addtaxa-single input:visible:last').focus()
}
addTaxonField()
$('#addtaxa .modal-footer .btn-primary').click(function() {
  loadingClickForLink.apply(this)
  if ($('#addtaxa-single:visible').length > 0) {
    addTaxaSingle()
  } else if ($('#addtaxa-place:visible').length > 0) {
    addTaxaFromPlace()
  } else if ($('#addtaxa-eol:visible').length > 0) {
    addTaxaFromEol()
  } else if ($('#addtaxa-paste:visible').length > 0) {
    addTaxaFromPaste()
  } else {
    completeAddTaxa()
  }
})
window.addingTaxonIds = []
function addTaxaSingle() {
  var $inputs = $('#addtaxa-single input[name=taxon_id]')
  window.addingTaxonIds = $inputs.map(function() { var v = $(this).val(); return v == '' ? null : v}).get()
  if (addingTaxonIds.length == 0) {
    checkAddingTaxaFor(null)
  }
  $inputs.each(function() {
    var taxonId = $(this).val()
    if (!parseInt(taxonId) || parseInt(taxonId) <= 0) return
    $.post("/guide_taxa.json", {"guide_taxon[guide_id]": GUIDE.id, "guide_taxon[taxon_id]": taxonId, partial: "guides/guide_taxon_row"})
      .success(function(json, status, xhr) {
        $('#guide_taxa .nocontent').remove()
        $('#guide_taxa').prepend(json.guide_taxon.html)
        $('#guide_taxa .guide_taxon:first').labelize()
      })
      .error(function(xhr) {
        var errors = $.parseJSON(xhr.responseText)
        alert(I18n.t('there_were_problems_adding_taxa', {errors: errors.join(', ')}))
      })
      .complete(function() {
        checkAddingTaxaFor(taxonId)
      })
  })
}
function completeAddTaxa() {
  var btn = $('#addtaxa .modal-footer .btn-primary')
  btn.show()
  btn.attr('disabled', false).removeClass('disabled description')
  btn.val(btn.data('original-value'))
  btn.siblings('.loadingclick').hide()
  $('#addtaxa').modal('hide')
  bindDeleteButtons()
}
function checkAddingTaxaFor(taxonId) {
  var i = window.addingTaxonIds.indexOf(taxonId)
  if (i >= 0) {
    window.addingTaxonIds.splice(i, 1)
  }
  if (window.addingTaxonIds.length == 0) {
    $('#addtaxa-single').html('')
    addTaxonField()
    completeAddTaxa()
  }
}
function addTaxaFromPlace() {
  var placeId = $('#addtaxa-place .placechooser').val(),
      taxonId = $('#addtaxa-place .taxonchooser').val(),
      rank = $('#addtaxa-place select[name=rank]').val()
  $.post(
    '/guides/'+GUIDE.id+'/import_taxa', 
    {
      taxon_id: taxonId, 
      place_id: placeId, 
      rank:rank, 
      partial: "guides/guide_taxon_row"
    }, 
    addImportedTaxaFromJSON, 
    'json'
  ).complete(function() {
    completeAddTaxa()
  })
}
function addImportedTaxaFromJSON(json) {
  if (json.error) {
    alert(json.error)
    return
  }
  for (var i = json.guide_taxa.length - 1; i >= 0; i--) {
    if (json.guide_taxa[i].html) {
      $('#guide_taxa .nocontent').remove()
      $('#guide_taxa').prepend(json.guide_taxa[i].html)
      $('#guide_taxa .guide_taxon:first').labelize()
    }
  }
}
function addTaxaFromEol() {
  var eolCollectionUrl = $('#addtaxa-eol input:first').val()
  $.post(
    '/guides/'+GUIDE.id+'/import_taxa', 
    {
      eol_collection_url: eolCollectionUrl, 
      partial: "guides/guide_taxon_row"
    }, 
    addImportedTaxaFromJSON, 
    'json'
  ).complete(function() {
    completeAddTaxa()
  })
}
function addTaxaFromPaste() {
  $.post(
    '/guides/'+GUIDE.id+'/import_taxa', 
    {
      names: $('#addtaxa-paste textarea:first').val(), 
      partial: "guides/guide_taxon_row"
    }, 
    addImportedTaxaFromJSON, 
    'json'
  ).complete(function() {
    completeAddTaxa()
  })  
}

function bindDeleteButtons() {
  $('.guide_taxon .delete').not('.deleteBound').bind('ajax:before', function() {
    $(this).parents('.guide_taxon').slideUp()
  }).bind('ajax:success', function() {
    $(this).parents('.guide_taxon').remove()
  }).addClass('deleteBound')
}
bindDeleteButtons()

function incrementLoadingStatus(options) {
  options = options || {}
  var status = $('.bigloading.status').text(),
      matches = status.match(/ (\d+) of (\d+)/)
  if (!matches || !matches[1]) { return }
  var current = parseInt(matches[1]),
      total = matches[2],
      verb = options.verb || I18n.t('saving_verb')
  $('.bigloading.status').text(I18n.t('verbing_x_of_y', {verb: verb, x: current + 1, y: total}))
}
function deleteGuideTaxon(options) {
  var options = options || {}
  var container = $('#guide_taxa'),
      recordContainer = $(this).parents('form:first'),
      params = '',
      recordId = $(this).data('guide-taxon-id') || $(this).attr('href').match(/\d+$/)[0]
  var nextMethod = function() {
    if (options.chain) {
      var link = recordContainer.nextAll().has('input[type=checkbox]:checked').find('.delete').get(0)
      if (link) {
        incrementLoadingStatus({verb: I18n.t('deleting_verb')})
        deleteGuideTaxon.apply(link, [options])
      } else {
        container.shades('close')
      }
    }
  }
  if (recordId && recordId != '') {
    params += '&_method=DELETE'
    url = '/guide_taxa/'+recordId
  } else {
    recordContainer.hide()
    nextMethod()
    recordContainer.remove()
    return
  }
  $.post(url, params, function(data, status) {
    recordContainer.slideUp(function() {
      nextMethod()
      recordContainer.remove()
    })
  }, 'json').error(function(xhr) {
    var json = eval('(' + xhr.responseText + ')')
    recordContainer.removeClass('success')
    recordContainer.addClass('error')
    if (json.full_messages) {
      errors = json.full_messages
    } else {
      var errors = ""
      for (var key in json.errors) {
        errors += key.replace(/_/, ' ') + ' ' + json.errors[key]
      }
    }
    recordContainer.find('.message td').html(errors)
    recordContainer.effect('highlight', {color: 'lightpink'}, 1000)
    nextMethod()
  })
}
function removeSelected() {
  $selection = $('.guide_taxon').has('input[type=checkbox]:checked')
  if ($selection.length == 0) return false
  if (confirm(I18n.t('are_you_sure_you_want_to_remove_these_x_taxa?', {x: $selection.length}))) {
    var msg = I18n.t('verbing_x_of_y', {verb: I18n.t('deleting_verb'), x: 1, y: $selection.length})
    engageShades(msg)
    var link = $selection.find('.delete:first').get(0)
    deleteGuideTaxon.apply(link, [{chain: true}])
  }
}
$('.navbar-search input').keyup(function(e) {
  var q = $(this).val()
  if (!q || q == '') {
    $('.guide_taxon').show()
    return
  }
  $('.guide_taxon').each(function() {
    if ($(this).data('search-name').match(q)) {
      $(this).show()
    } else {
      $(this).hide()
    }
  })
})
$('#selectall').click(function() {
  $('.guide_taxon input:checkbox:visible').attr('checked', true).change()
})
$('#selectnone').click(function() {
  $('.guide_taxon input:checkbox').attr('checked', false).change()
})
function updatePositions(container, sortable) {
  $selection = $(sortable+':visible', container)
  $selection.each(function() {
    $('input[name*="position"]', this).val($selection.index(this) + 1)
  })
}
$('#guide_taxa').sortable({
  items: "> form",
  cursor: "move",
  placeholder: 'row stacked sorttarget',
  update: function(event, ui) {
    updatePositions("#guide_taxa", "form")  
    if (!window.updateGuideTaxaTimeout) {
      window.updateGuideTaxaTimeout = setTimeout('updateGuideTaxa()', 5000)
    };
  }
})
function updateGuideTaxa() {
  window.updateGuideTaxaTimeout = null
  saveGuideTaxon.apply($('#guide_taxa form:first').get(0), [{chain: true, unchecked: true}])
}
function saveGuideTaxon(options) {
  var options = options || {}
  var container = $('#guide_taxa'),
      recordContainer = $(this)
  var nextMethod = function() {
    if (options.chain) {
      var next
      if (options.unchecked) {
        next = recordContainer.nextAll('form').get(0) 
      } else {
        next = recordContainer.nextAll('form').has('input[type=checkbox]:checked:visible').get(0)
      }
      if (next) {
        incrementLoadingStatus()
        saveGuideTaxon.apply(next, [options])
      } else {
        container.shades('close')
      }
    }
  }
  var url = $(this).attr('action'),
      params = $(this).serialize()
  $.post(url, params, function(data, status) {
    nextMethod()
  }, 'json').error(function(xhr) {
    var json = eval('(' + xhr.responseText + ')')
    nextMethod()
  })
}
if (iNaturalist && iNaturalist.Map) {
  window.map = iNaturalist.Map.createMap({
    div: $('#map').get(0)
  })
  var preserveViewport = GUIDE.latitude && GUIDE.zoom_level
  map.setMapTypeId(GUIDE.map_type)
  if (GUIDE.zoom_level) {
    map.setZoom(GUIDE.zoom_level)
  }
  $('#map_search').latLonSelector({
    mapDiv: $('#map').get(0),
    map: map,
    noAccuracy: true
  })
  google.maps.event.addListener(map, 'maptypeid_changed', function() {
    $('#guide_map_type').val(window.map.getMapTypeId())
  })
  google.maps.event.addListener(map, 'zoom_changed', function() {
    $('#guide_zoom_level').val(window.map.getZoom())
  })
}
window.firstRun = true
$('#guide_place_id').chooser({
  collectionUrl: '/places/autocomplete.json',
  resourceUrl: '/places/{{id}}.json?partial=autocomplete_item',
  chosen: PLACE,
  afterSelect: function(item) {
    $('#guide_place_id').data('json', item)
    if (window.firstRun && PLACE) {
      window.firstRun = false
    } else {
      $("#guide_latitude").val(item.latitude)
      $("#guide_longitude").val(item.longitude)
      if (item.swlat) {
        var bounds = new google.maps.LatLngBounds(
          new google.maps.LatLng(item.swlat, item.swlng),
          new google.maps.LatLng(item.nelat, item.nelng)
        )
        map.fitBounds(bounds)
      }
      $("#guide_latitude").val(item.latitude).change()
    }
  }
})

$('#addtags .modal-footer .btn-primary').click(function() {
  if ($('#addtags-colors:visible').length > 0) {
    addColorTags()
  } else if ($('#addtags-ranks:visible').length > 0) {
    addRankTags()
  } else {
    addYourTags()
  }
  $('#addtags').modal('hide')
})

function addColorTags() {
  engageShades(I18n.t('tagging'))
  $.ajax({
    url: '/guides/'+GUIDE.id+'/add_color_tags',
    type: 'put',
    dataType: 'json',
    data: $('#guide_taxa form.edit_guide_taxon:visible input[type=checkbox]:checked').serialize()
  }).success(function(json) {
    $('#guide_taxa').shades('close')
    $.each(json, function() {
      $('#edit_guide_taxon_'+this.id+' [name*=tag_list]').val(this.tag_list.join(', '))
    })
  }).error(function(arguments) {
    alert('Failed to add tags')
  })
}

function addRankTags() {
  engageShades(I18n.t('tagging'))
  var data = $('#guide_taxa form.edit_guide_taxon:visible input[type=checkbox]:checked').serialize() +
             '&' + $('#addtags-ranks :input').serialize(),
      rank = $('#addtags-ranks :input[name=rank]').val()

  $.ajax({
    url: '/guides/'+GUIDE.id+'/add_tags_for_rank/'+rank,
    type: 'put',
    dataType: 'json',
    data: data
  }).success(function(json) {
    $('#guide_taxa').shades('close')
    $.each(json, function() {
      $('#edit_guide_taxon_'+this.id+' [name*=tag_list]').val(this.tag_list.join(', '))
    })
  }).error(function(arguments) {
    alert('Failed to add tags')
  })
}

function addYourTags() {
  var tags = ($('#addtags-your input[type=text]').val() || "").split(',').map(function(t) { return $.trim(t) })
  $selection = $('#guide_taxa form.edit_guide_taxon:visible').has('input[type=checkbox]:checked')
  if (tags.length == 0 || $selection.length == 0) {
    $('#addtags').modal('hide')
    return
  }
  var msg = I18n.t('verbing_x_of_y', {verb: I18n.t('saving_verb'), x: 1, y: $selection.length})
  engageShades(msg)
  $selection.each(function() {
    var input = $('input[name*=tag_list]', this)
    var val = $(input).val(),
        existing
    if (val) {
      existing = val.split(',').map(function(t) { return $.trim(t) })
    } else {
      existing = []
    }
    var newTags = $.unique(existing.concat(tags))
    $(input).val(newTags.join(', '))
  })
  saveGuideTaxon.apply($selection.get(0), [{chain: true}])
}

$('#removetags .modal-footer .btn-primary').click(function() {
  var tags = ($('#removetags input[type=text]').val() || "").split(',').map(function(t) { return $.trim(t) })
  $selection = $('#guide_taxa form.edit_guide_taxon:visible').has('input[type=checkbox]:checked')
  if (tags.length == 0 || $selection.length == 0) {
    $('#removetags').modal('hide')
    return
  }
  var msg = I18n.t('verbing_x_of_y', {verb: I18n.t('removing'), x: 1, y: $selection.length})
  engageShades(msg)
  $selection.each(function() {
    var input = $('input[name*=tag_list]', this)
    var existing = ($(input).val() || "").split(',').map(function(t) { return $.trim(t) })
    var newTags = []
    for (var i = 0; i < existing.length; i++) {
      if ($.inArray(existing[i], tags) < 0) {
        newTags.push(existing[i])
      }
    }
    $(input).val(newTags.join(', '))
  })
  saveGuideTaxon.apply($selection.get(0), [{chain: true}])
  $('#removetags').modal('hide')
})

function addTag(tag) {
  var tag = $.trim(tag)
  var tags
  if ($.trim($('#addtags-your input[type=text]').val()) == '') {
    tags = []
  } else {
    tags = $('#addtags-your input[type=text]').val().split(',').map($.trim)
  }
  if (tags.indexOf(tag) < 0) {
    tags.push(tag)
    $('#addtags-your input[type=text]').val(tags.join(', '))
  }
}

function removeTag(tag) {
  var tag = $.trim(tag)
  var tags
  if ($.trim($('#removetags input[type=text]').val()) == '') {
    tags = []
  } else {
    tags = $('#removetags input[type=text]').val().split(',').map($.trim)
  }
  if (tags.indexOf(tag) < 0) {
    tags.push(tag)
    $('#removetags input[type=text]').val(tags.join(', '))
  }
}

function removeAllTags() {
  if (!confirm(I18n.t('are_you_sure_you_want_to_remove_all_tags'))) {
    return
  }
  engageShades(I18n.t('removing'))
  $.ajax({
    url: '/guides/'+GUIDE.id+'/remove_all_tags',
    type: 'put',
    dataType: 'json'
  }).success(function(json) {
    $('#guide_taxa').shades('close')
    $(':input[name*=tag_list]').val('')
  }).error(function(arguments) {
    alert('Failed to remove tags')
    $('#guide_taxa').shades('close')
  })
}

$('.guide_taxon input[name*=tag_list]').on('change', function() {
  saveGuideTaxon.apply($(this).parents('form:first').get(0))
})

$('#guide_taxa .guide_taxon').labelize()
$('input[name="guide_eol_update_flow_task[options][sections]"]').on('change', function() {
  if ($(this).is(':checked')) {
    $('input[name="guide_eol_update_flow_task[options][overview]"]').enable()
    $('#eol_subjects :input').enable()
  } else {
    $('input[name="guide_eol_update_flow_task[options][overview]"]').disable()
    $('#eol_subjects :input').disable()
  }
})
$('input[name="guide_eol_update_flow_task[options][overview]"]').on('change', function() {
  if ($(this).val() == "true") {
    $('#eol_subjects').hide()
  } else {
    $('#eol_subjects').show()
  }
})

$('#new_guide_eol_update_flow_task .btn-primary').click(function() {
  $selection = $('#guide_taxa form.edit_guide_taxon:visible').has('input[type=checkbox]:checked')
  var data = $('#new_guide_eol_update_flow_task').serializeArray()
  for (var i = 0; i < $selection.length; i++) {
    var guideTaxonId = $($selection[i]).attr('action').match(/\d+$/)[0]
    if (guideTaxonId) {
      data.push({name: "guide_eol_update_flow_task[inputs_attributes]["+i+"][resource_type]", value: 'GuideTaxon'})
      data.push({name: "guide_eol_update_flow_task[inputs_attributes]["+i+"][resource_id]", value: guideTaxonId})
    }
  }
  loadingClickForButton.apply($('.modal:visible input[data-loading-click]').get(0), [{ajax:false}])
  $.ajax({
    url: '/flow_tasks',
    type: 'post',
    dataType: 'json',
    data: data
  }).success(function(json) {
    runFlowTask('/flow_tasks/'+json.id+'/run.json')
  }).error(function(arguments) {
    var btn = $('.modal:visible input[data-loading-click]')
    btn.attr('disabled', false).removeClass('disabled description')
    btn.val(btn.data('original-value'))
    alert("Error: ", arguments)
  })

  return false
})

window.runFlowTask = function(runUrl) {
  $('.modal:visible .patience').show()
  $.ajax({
    url: runUrl,
    statusCode: {
      // Accepted: request acnkowledged but file hasn't been generated
      202: function() {
        setTimeout('runFlowTask("'+runUrl+'")', 5000)
      },
      // OK: file is ready
      200: function(flowTask) {
        $('.modal:visible .patience').hide()
        var btn = $('.modal:visible input[data-loading-click]')
        btn.attr('disabled', false).removeClass('disabled description')
        btn.val(btn.data('original-value'))
        window.location.reload()
      }
    }
  }).error(function(arguments) {
    var btn = $('.modal:visible input[data-loading-click]')
    btn.attr('disabled', false).removeClass('disabled description')
    btn.val(btn.data('original-value'))
    alert("Error: ", arguments)
    $('.modal:visible .patience').hide()
  })
}
$('#guide_eol_update_flow_task_options_subjects').multiselect()
$('#eolupdate').on('shown.bs.modal', function () {
  $('body').css({height: '100%', overflow:'hidden'})
  var count = $('.guide_taxon input[type=checkbox]:checked').length,
      val = I18n.t('update_x_selected_taxa', {count: count})
  if (count == 0) {
    val = I18n.t('you_must_select_at_least_one_taxon')
  }
  if (count > 0) {
    $('#eolupdate .modal-footer .btn-primary').enable().val(val)
  } else {
    $('#eolupdate .modal-footer .btn-primary').disable().val(val)
  }
})
$('#eolupdate').on('hidden', function () {
  $('body').css({height: 'auto', overflow:'auto'})
})
function engageShades(msg) {
  $('#guide_taxa').loadingShades(msg, {
    cssClass: 'bigloading',
    top: $('body').scrollTop() + $(window).height()/2 - 100 + 'px'
  })
}
$('#guide_users').bind('cocoon:after-insert', function(e, inserted_item) {
  $('.guide-user-chooser').chooser({
    queryParam: 'q',
    collectionUrl: '/people/search.json',
    resourceUrl: '/people/{{id}}.json'
  })
})
