$('#guide_taxon_taxon_id:visible').chooser({
  collectionUrl: '/taxa/autocomplete.json',
  resourceUrl: '/taxa/{{id}}.json?partial=chooser',
})
$('#import_photos_dialog').on('shown.bs.modal', function() {
  $content = $('#flickr_photos')
  if ($content.hasClass('loaded')) {
    return
  }
  $content.photoSelector(photoSelectorOptions)
  $content.addClass('loaded')
})
var photoSelectorOptions = {
  defaultQuery: GUIDE_TAXON.name,
  skipLocal: true,
  baseURL: '/flickr/photo_fields',
  licensed: true,
  bootstrap: true,
  urlParams: {
    authenticity_token: $('meta[name=csrf-token]').attr('content'),
    limit: 42,
    partial: 'bootstrap_photo_list_form'
  }
}
$('#import_photos_dialog [data-toggle="tab"]').on('show.bs.tab', function(e) {
  var $tab = $(e.target),
      provider = $tab.data('provider'),
      $content = $($tab.attr('href'))
  if ($content.hasClass('loaded')) {
    return
  }
  switch (provider) {
    case 'site':
      var baseURL = GUIDE_TAXON.taxon_id ?
        '/taxa/'+GUIDE_TAXON.taxon_id+'/observation_photos' : '/taxa/observation_photos'
      $content.photoSelector($.extend(true, {}, photoSelectorOptions, {baseURL: baseURL}))
      break
    case 'eol':
      $content.photoSelector(
        $.extend(true, {}, photoSelectorOptions, {baseURL: '/eol/photo_fields?eol_page_id='+EOL_PAGE_ID})
      )
      break
    case 'wikimedia_commons':
      $content.photoSelector(
        $.extend(true, {}, photoSelectorOptions, {taxon_id: GUIDE_TAXON.id, baseURL: '/wikimedia_commons/photo_fields'})
      )
      break
    default:
      $content.photoSelector(photoSelectorOptions)
      break
  }
  $content.addClass('loaded')
})
$('#import_photos_dialog .modal-footer .btn-primary').click(function() {
  $('#import_photos_dialog .photo').has(':checkbox:checked').each(function() {
    var data = $(this).data()
    $('#guide_photos_row .btn-add-photo').click()
    $('.guide-photo-fields:last img').attr('src', data.smallUrl)
    $('.guide-photo-fields:last :input[name*="native_photo_id"]').val(data.nativePhotoId)
    $('.guide-photo-fields:last :input[name*="type"]').val(data.type)
    $('.guide-photo-fields:last .photo_id_input').val(data.id)
    $('.guide-photo-fields:last .local_photo_fields').hide()
  })
  updatePositions("#guide_photos", ".nested-fields")
  $('#import_photos_dialog').modal('hide')
})
$('#import_sections_dialog').on('shown.bs.modal', function(e) {
  sectionsForTab($('.tab-pane:visible', this))
})
$('#import_sections_dialog [data-toggle="tab"]').on('shown.bs.tab', function(e) {
  sectionsForTab($($(e.target).attr('href')))
})
function sectionsForTab(current) {
  if (current.hasClass('loaded')) {
    return
  }
  var provider = current.attr('id').split('_')[0]
  $.getJSON('/guide_sections/import?provider='+provider+'&q='+GUIDE_TAXON.name+'&eol_page_id='+EOL_PAGE_ID+'&guide_taxon_id='+GUIDE_TAXON.id, function(json) {
    current.html('')
    if (!json || json.length == 0) {
      current.html("<p>"+I18n.t('no_sections_available')+"</p>")
    } else {
      $.each(json, function() {
        current.append(sectionToHtml(this))
      })
    }
  })
  current.addClass('loaded')
}
function sectionToHtml(section) {
  var div = $('<div></div>').addClass('lined stacked')
  div.append(
    $('<a class="right btn btn-default">'+I18n.t('import')+'</a>').click(function() {addSection(section)})
  )
  var attribution = $('<div class="small meta"></div>').html(section.attribution)
  if (section.source_url) {
    var link = $('<a></a>').attr('href', section.source_url).attr('target', '_blank')
    attribution = attribution.wrap(link)
  }
  div.append(
    $('<h3 class="title">'+section.title+'</h3>'),
    $('<div class="stacked"></div>').html(section.description),
    attribution
  )
  return div
}
function addSection(section) {
  $('#guide_sections_row .btn-add-section').click()
  $.each(['title', 'description', 'rights_holder', 'license', 'source_id', 'source_url'], function() {
    $('.guide-section-fields:last .'+this+'_field :input').val(section[this])
    $('.guide-section-fields:last .'+this+'_field .mirror').html(section[this])
  })
}
$('#import_ranges_dialog').on('shown.bs.modal', function() {
  var current = $('.tab-pane:visible', this)
  if (current.hasClass('loaded')) {
    return
  }
  var provider = current.attr('id').split('_')[0],
      eolPageId = ''
  $.getJSON('/guide_ranges/import?provider='+provider+'&q='+GUIDE_TAXON.name+'&eol_page_id='+EOL_PAGE_ID, function(json) {
    if (!json || json.length == 0) {
      current.html("<p>"+I18n.t('no_range_data_available')+"</p>")
    } else {
      var ul = $('<div class="row"></div>')
      $.each(json, function() {
        ul.append(rangeToHtml(this))
      })
      current.html(ul)
    }
  }).error(function() {
  })
  current.addClass('loaded')
})
function rangeToHtml(range) {
  var div = $('<div></div>').addClass('thumbnail text-center')
  div.append($('<img/>').attr('src', range.thumb_url).addClass('stacked'))
  div.append(
    $('<a class="btn btn-default">'+I18n.t('import')+'</a>').click(function() {addRange(range)})
  )
  var attribution = $('<div class="small meta upstacked"></div>').html(range.attribution)
  if (range.source_url) {
    var link = $('<a></a>') .attr('href', range.source_url).attr('target', '_blank')
    attribution = attribution.wrap(link)
  }
  div.append(attribution)
  return $('<div class="col-xs-3"></div>').html(div)
}
function addRange(range) {
  $('#guide_ranges_row .btn-add-range').click()
  $('.guide-range-fields:last img').attr('src', range.medium_url)
  $('.guide-range-fields:last .local_fields').hide()
  $.each(['thumb_url', 'medium_url', 'original_url', 'rights_holder', 'license', 'source_id', 'source_url'], function() {
    $('.guide-range-fields:last .'+this+'_field :input').val(range[this])
    $('.guide-range-fields:last .'+this+'_field .mirror').html(range[this])
  })
  $('.guide-range-fields:last .form-group :input').lock()
}
function updatePositions(container, sortable) {
  $selection = $(sortable+':visible', container)
  $selection.each(function() {
    $('input[name*="position"]', this).val($selection.index(this) + 1)
  })
}
$('#guide_photos').sortable({
  items: ".nested-fields",
  cursor: "move",
  placeholder: 'row stacked sorttarget',
  update: function(event, ui) {
    updatePositions("#guide_photos", ".nested-fields")  
  }
})
$('#guide_photos').bind('cocoon:before-remove', function(e, item) {
  $(this).data('remove-timeout', 1000)
  $(item).slideUp(function() {
    updatePositions("#guide_photos", ".nested-fields")
  })
})
$('#guide_sections').sortable({
  items: ".nested-fields",
  cursor: "move",
  placeholder: 'row stacked sorttarget',
  update: function(event, ui) {
    updatePositions("#guide_sections", ".nested-fields")  
  }
})
$('#guide_ranges').sortable({
  items: ".nested-fields",
  cursor: "move",
  placeholder: 'row stacked sorttarget',
  update: function(event, ui) {
    updatePositions("#guide_ranges", ".nested-fields")  
  }
})
$('#guide_sections').bind('cocoon:before-remove', function(e, item) {
  $(this).data('remove-timeout', 1000)
  $(item).slideUp(function() {
    updatePositions("#guide_sections", ".nested-fields")  
  })
})
$('#guide_photos').bind('cocoon:after-insert', function(e, item) {
  updatePositions("#guide_photos", ".nested-fields")
})
$('#guide_sections').bind('cocoon:after-insert', function(e, item) {
  updatePositions("#guide_sections", ".nested-fields")
})
$('#guide_ranges').bind('cocoon:after-insert', function(e, item) {
  updatePositions("#guide_ranges", ".nested-fields")
})
$('#guide_ranges').bind('cocoon:before-remove', function(e, item) {
  $(this).data('remove-timeout', 1000)
  $(item).slideUp()
})
$('#guide_sections').on('change', 'input[type=text]', function() {
  $(this).parents('.nested-fields:first').find('input[name*=modified_on_create]').val(true)
})
function addTag(tag) {
  var tag = $.trim(tag)
  var tags
  if ($.trim($('#guide_taxon_tag_list').val()) == '') {
    tags = []
  } else {
    tags = $('#guide_taxon_tag_list').val().split(',').map($.trim)
  }
  if (tags.indexOf(tag) < 0) {
    tags.push(tag)
    $('#guide_taxon_tag_list').val(tags.join(', '))
  }
}

function addPhotoTag(btn, tag) {
  var tag = $.trim(tag),
      tags,
      input = $(btn).parents('.photo-tags:first').find('.tag_list')
  if ($.trim(input.val()) == '') {
    tags = []
  } else {
    tags = input.val().split(',').map($.trim)
  }
  if (tags.indexOf(tag) < 0) {
    tags.push(tag)
    input.val(tags.join(', '))
  }
}

