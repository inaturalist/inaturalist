var placeLayer;

function rulify() {
  $('#new_operand_id').chooser({
    collectionUrl: '/places/autocomplete.json?with_geom=t',
    resourceUrl: '/places/{{id}}.json?partial=autocomplete_item',
    chosen: eval('(' + $('new_operand_id').attr('data-json') + ')'),
    afterSelect: function(item) {
      $('#new_operand_type').val("Place")
    },
    afterClear: function() {
      $('#new_operand_type').val('')
    }
  })
  
  $('#taxon_q').simpleTaxonSelector({
    taxonIDField: $('#new_operand_id'),
    afterSelect: function() {
      $('#new_operand_type').val("Taxon")
    },
    afterUnselect: function() {
      $('#new_operand_type').val('')
    }
  })
  $('#taxon_selector').hide()
  
  $('.observationrules .togglelink').click()
  
  $('.operator_field select').change(function() {
    if ($(this).val() == 'observed_in_place?') {
      $('#place_selector').show()
    } else {
      $('#place_selector').hide()
    }
    if ($(this).val() == 'in_taxon?') {
      $('#taxon_selector').show()
    } else {
      $('#taxon_selector').hide()
    }
  })
  $('.operator_field select').change()
}

function newProjectObservationField(markup) {
  var currentField = $('.observation_field_chooser').chooser('selected')
  if (!currentField || typeof(currentField) == 'undefined') {
    alert('Please choose a field type')
    return
  }
  if ($('#observation_field_'+currentField.recordId).length > 0) {
    alert('You already have a field for that type')
    return
  }
  
  $('.project_observation_fields').append(markup)
  fieldify({observationField: currentField})
}

function fieldify(options) {
  options = options || {}
  $('.project_observation_field').not('.fieldified').each(function() {
    var lastName = $('.project_observation_field.fieldified:last input').attr('name')
    if (lastName) {
      var index = parseInt(lastName.match(/project_observation_fields_attributes\]\[(\d+)\]/)[1]) + 1
    } else {
      var index = 0
    }
    
    $(this).addClass('fieldified')
    var input = $('.ofv_input input.text', this)
    var currentField = options.observationField || $.parseJSON($(this).attr('data-json'))
    if (!currentField) return
    currentField.recordId = currentField.recordId || currentField.id
    
    $(this).attr('id', 'observation_field_'+currentField.recordId)
    $('.title', this).html(currentField.name)
    if (currentField.allowed_values && currentField.allowed_values.length > 0) {
      $('.allowed span', this).html(currentField.allowed_values)
      $('.allowed', this).show()
    } else {
      $('.allowed', this).hide()
    }
    $('.description', this).html(currentField.description)
    $('.editlink', this).attr('href', '/observation_fields/'+currentField.id+'/edit')
    $('input[name*="observation_field_id"]', this).val(currentField.recordId)
    $('input', this).each(function() {
      var newName = $(this).attr('name')
        .replace(
          /project_observation_fields_attributes\]\[(\d+)\]/, 
          'project_observation_fields_attributes]['+index+']')
      $(this).attr('name', newName)
    })
  })
  updateProjectObservationFieldPositions()
}

function updateProjectObservationFieldPositions() {
  $('.project_observation_fields li').each(function() {
    $('input[name*="position"]', this).val($('li', $(this).parent()).index(this))
  })
}

$(document).ready(function() {
  $('.observation_field_chooser').chooser({
    collectionUrl: '/observation_fields.json',
    resourceUrl: '/observation_fields/{{id}}.json',
    afterSelect: function(item) {
      $('.observation_field_chooser').parents('.ui-chooser:first').next('.button').click()
      $('.observation_field_chooser').chooser('clear')
    }
  })
  $('#createfieldbutton').click(ObservationFields.newObservationFieldButtonHandler)
  fieldify()
  $('.project_observation_fields').sortable({
    placeholder: 'sortabletarget',
    update: function(event, ui) {
      updateProjectObservationFieldPositions()
    }
  })

  window.map = iNaturalist.Map.createMap({
    div: $('#map').get(0)
  })
  var preserveViewport = PROJECT.latitude && PROJECT.zoom_level
  if (typeof(KML_ASSET_URLS) != 'undefined' && KML_ASSET_URLS != null) {
    for (var i=0; i < KML_ASSET_URLS.length; i++) {
      lyr = new google.maps.KmlLayer(KML_ASSET_URLS[i], {preserveViewport: preserveViewport})
      map.addOverlay('KML Layer', lyr)
    }
  }
  map.setMapTypeId(PROJECT.map_type)
  if (PROJECT.zoom_level) {
    map.setZoom(PROJECT.zoom_level)
  }
  $('#map_search').latLonSelector({
    mapDiv: $('#map').get(0),
    map: map,
    noAccuracy: true
  })
  google.maps.event.addListener(map, 'maptypeid_changed', function() {
    $('#project_map_type').val(window.map.getMapTypeId())
  })
  google.maps.event.addListener(map, 'zoom_changed', function() {
    $('#project_zoom_level').val(window.map.getZoom())
  })

  window.firstRun = typeof(PROJECT.place_id) != 'undefined' && PROJECT.place_id != null
  $('#project_place_id').chooser({
    collectionUrl: '/places/autocomplete.json?with_geom=t',
    resourceUrl: '/places/{{id}}.json?partial=autocomplete_item',
    chosen: PLACE,
    afterSelect: function(item) {
      $('#project_place_id').data('json', item)
      if (window.firstRun) {
        window.firstRun = false
      } else {
        $("#project_latitude").val(item.latitude)
        $("#project_longitude").val(item.longitude)
        if (item.swlat) {
          var bounds = new google.maps.LatLngBounds(
            new google.maps.LatLng(item.swlat, item.swlng),
            new google.maps.LatLng(item.nelat, item.nelng)
          )
          map.fitBounds(bounds)
        }
        $("#project_latitude").val(item.latitude).change()
      }
      if (item.id && $('input[name="project[prefers_place_boundary_visible]"]:visible').checked) {
        placeLayer = window.map.addPlaceLayer({ place: { id: item.id } });
      }
    }
  })
  $('input[name="project[prefers_place_boundary_visible]"]:visible').change(function() {
    var place = PLACE || $('#project_place_id').data('json');
    if (! place) { return; }
    if (this.checked) {
      placeLayer = window.map.addPlaceLayer({ place: { id: place.id } });
    } else {
      map.overlayMapTypes.setAt(placeLayer - 1, null);
    }
  })
  $('input[name="project[prefers_place_boundary_visible]"]:visible').change()
  $('#project_project_type').change(function() {
    if ($(this).val() == 'bioblitz') {
      $('#bioblitz').show( );
      $('#project_start_time, #project_end_time').attr('required', true)
      $('#project_start_time, #project_end_time').each(function () {
        if (!$(this).hasClass('hasDatepicker')) {
          $(this).iNatDatepicker({
            time:true, 
            timezone: currentTimeZone().offset,
            timeFormat: 'HH:mm:ssz',
            separator: 'T',
            showSecond: false,
            showTimezone: false,
            maxDate: "+1Y",
            yearRange: "c-100:c+1"
          })
        }
      })
    } else {
      $('#bioblitz').hide( );
      $('#project_start_time, #project_end_time').attr('required', false)
    }
  });
  $( "#project_prefers_aggregation" ).change( function( ) {
    if( $(this).attr( "checked" ) ) {
      $( "#last_aggregated_at" ).show( );
    } else {
      $( "#last_aggregated_at" ).hide( );
    }
  });
  $('#project_start_time:visible, #project_end_time:visible').each(function () {
    $(this).attr('required', true)
    if (!$(this).hasClass('hasDatepicker')) {
      $(this).iNatDatepicker({
        time:true, 
        timezone: currentTimeZone().offset,
        timeFormat: 'HH:mm:ssz',
        separator: 'T',
        showSecond: false,
        showTimezone: false,
        maxDate: null
      })
    }
  })

  updateObservedAfterRule( );
  $( ".start_time_field input" ).on( "change", function( ) {
    updateObservedAfterRule( );
  });

  updateObservedBeforeRule( );
  $( ".end_time_field input" ).on( "change", function( ) {
    updateObservedBeforeRule( );
  });

})

var updateObservedAfterRule = function( ) {
  var value = $( ".start_time_field:visible input" ).val( );
  if ( value ) {
    $( "li#observed_after_rule" ).
      text( I18n.t( "must_be_observed_after", { operand: value } ) ).
      css( { display: "list-item" } );
  } else {
    $( "li#observed_after_rule" ).css( { display: "none" } );
  }
};

var updateObservedBeforeRule = function( ) {
  var value = $( ".end_time_field:visible input" ).val( );
  if ( value ) {
    $( "li#observed_before_rule" ).
      text( I18n.t( "must_be_observed_before", { operand: value } ) ).
      css( { display: "list-item" } );
  } else {
    $( "li#observed_before_rule" ).css( { display: "none" } );
  }
};
