$(document).ready(function() {
  $('.species_guess').simpleTaxonSelector();
  $('.observed_on_string').iNatDatepicker();
  try {
    var map = iNaturalist.Map.createMap({
      div: $('#map').get(0),
      mapTypeId: google.maps.MapTypeId.HYBRID
    })
    if (typeof(PLACE) != 'undefined' && PLACE) {
      map.setPlace(PLACE, {
        kml: PLACE_GEOMETRY_KML_URL,
        click: function(e) {
          $.fn.latLonSelector.handleMapClick(e)
        }
      })
      map.controls[google.maps.ControlPosition.TOP_RIGHT].push(new iNaturalist.OverlayControl(map))
    }
    $('.place_guess').latLonSelector({
      mapDiv: $('#map').get(0),
      map: map
    })
  } catch (e) {
    // maps didn't load
  }
  
  $('#mapcontainer').hover(function() {
    $('#mapcontainer .description').fadeOut()
  })
  
  // Setup taxon browser
  $('body').append(
    $('<div id="taxonchooser" class="clear modalbox dialog"></div>').append(
      $('<div id="taxon_browser" class="clear"></div>').append(
        $('<div class="loading status">Loading...</div>')
      )
    ).hide()
  );
  
  $('#taxonchooser').jqm({
    onShow: function(h) {
      h.w.fadeIn(500);
      if (h.w.find('#taxon_browser > .loading').length == 1) {
        h.w.find('#taxon_browser').load(
          '/taxa/search?partial=browse&js_link=true',
          {}, function() {TaxonBrowser.ajaxify()});
      }
    }
  });
  $('.observation_field_chooser').chooser({
    collectionUrl: 'http://'+window.location.host + '/observation_fields.json',
    resourceUrl: 'http://'+window.location.host + '/observation_fields/{{id}}.json',
    afterSelect: function(item) {
      $('.observation_field_chooser').parents('.ui-chooser:first').next('.button').click()
    }
  })
  
  $('#morefields .addfieldbutton').hide()
  $('#createfieldbutton').click(function() {
    var url = $(this).attr('href'),
        dialog = $('<div class="dialog"><span class="loading status">Loading...</span></div>')
    $(document.body).append(dialog)
    $(dialog).dialog({modal:true, title: "New observation field"})
    $(dialog).load(url, "format=js", function() {
      $('form', dialog).submit(function() {
        $.ajax({
          type: "post",
          url: $(this).attr('action'),
          data: $(this).serialize(),
          dataType: 'json'
        })
        .done(function(data, textStatus, XMLHttpRequest) {
          $(dialog).dialog('close')
          $('.observation_field_chooser').chooser('selectItem', data)
        })
        .fail(function (xhr, ajaxOptions, thrownError){
          alert(xhr.statusText)
        })
        return false
      })
    })
    return false
  })
  
  $('.observation_photos').each(function() {
    var authenticity_token = $(this).parents('form').find('input[name=authenticity_token]').val()
    if (window.location.href.match(/\/observations\/new/)) {
      var index = 0
    } else {
      var index = window.location.href.match(/\/observations\/(\d+)/)[1]
    }
    // The photo_fields endpoint needs to know the auth token and the index
    // for the field
    var options = {
      urlParams: {
        authenticity_token: authenticity_token,
        index: index,
        limit: 15,
        synclink_base: window.location.pathname
      }
    }
    if (DEFAULT_PHOTO_IDENTITY_URL) {
      options.baseURL = DEFAULT_PHOTO_IDENTITY_URL
    } else {
      options.baseURL = '/photos/local_photo_fields?context=user'
      options.queryOnLoad = false
    }
    if (PHOTO_IDENTITY_URLS && PHOTO_IDENTITY_URLS.length > 0) {
      options.urls = PHOTO_IDENTITY_URLS
    }
    $(this).photoSelector(options)
  })
  
  fieldify()
})

function handleTaxonClick(e, taxon) {
  $.fn.simpleTaxonSelector.selectTaxon($('.simpleTaxonSelector:first'), taxon);
  $('#taxonchooser').jqmHide();
}

function afterFindPlaces() {
  TaxonBrowser.ajaxify('#find_places')
}

function newObservationField(markup) {
  var currentField = $('.observation_field_chooser').chooser('selected')
  if (!currentField || typeof(currentField) == 'undefined') {
    alert('Please choose a field type')
    return
  }
  if ($('#observation_field_'+currentField.recordId).length > 0) {
    alert('You already have a field for that type')
    return
  }
  
  $('.observation_fields').append(markup)
  fieldify(currentField)
}

function fieldify(observationField) {
  $('.observation_field').not('.fieldified').each(function() {
    var lastName = $('.observation_field.fieldified:last input').attr('name')
    if (lastName) {
      var index = parseInt(lastName.match(/observation_field_values_attributes\]\[(\d+)\]/)[1]) + 1
    } else {
      var index = 0
    }
    
    $(this).addClass('fieldified')
    var input = $('.value_field input', this),
        currentField = observationField || $.parseJSON($(input).attr('data-json'))
    if (!currentField) return
    currentField.recordId = currentField.recordId || currentField.id
    
    $(this).attr('id', 'observation_field_'+currentField.recordId)
    $('.value_field label', this).html(currentField.name)
    $('.value_field .description', this).html(currentField.description)
    $('.observation_field_id', this).val(currentField.recordId)
    $('input', this).each(function() {
      var newName = $(this).attr('name')
        .replace(
          /observation_field_values_attributes\]\[(\d+)\]/, 
          'observation_field_values_attributes]['+index+']')
      $(this).attr('name', newName)
    })
    if (currentField.allowed_values && currentField.allowed_values != '') {
      var allowed_values = currentField.allowed_values.split('|')
      var select = $('<select></select>')
      for (var i=0; i < allowed_values.length; i++) {
        select.append($('<option>'+allowed_values[i]+'</option>'))
      }
      select.change(function() { input.val($(this).val()) })
      $(input).hide()
      $(input).after(select)
      select.change()
    } else if (currentField.datatype == 'numeric') {
      var newInput = input.clone()
      newInput.attr('type', 'number')
      input.after(newInput)
      input.remove()
    } else if (currentField.datatype == 'date') {
      $(input).iNatDatepicker({constrainInput: true})
    } else if (currentField.datatype == 'time') {
      $(input).timepicker({})
    }
  })
}
