/* eslint-disable */
function applyBatch(inputNames) {
  $.each(inputNames, function() {
    var checkedInput, input = $('#batchform :input[name="observation['+this+']"]')
    if (input.length > 1) { 
      checkedInput = $('#batchform :input[name="observation['+this+']"]:checked')
      if (checkedInput.length > 0) {
        input = checkedInput
      }
    }
    var batchVal = input.val()

    // Tags should append, not replace
    if ( this.match( /tag_list/ ) ) {
      var newTags = batchVal.split( "," ).map( function( t ) { return t.trim( ) } );
      $('#batchcol :input[name*="['+this+']"]').each( function( ) {
        var existingTags = ( $( this ).val( ) || "" ).split( "," ).map( function( t ) { return _.trim( t ); } );
        var tags = _.compact( _.uniq( existingTags.concat( newTags ) ) );
        $( this ).val( tags.join( ", " ) );
      } );
      return;
    }

    if (this.match(/geoprivacy/) && !batchVal) {
      batchVal = 'open'
    }
    if ($.trim(batchVal) != '') {
      if (checkedInput) {
        $('#batchcol :input[name*="['+this+']"][value='+batchVal+']').click()
      } else {
        $('#batchcol :input[name*="['+this+']"]').val(batchVal)
      }
    }
  })
}

function batchTaxon() {
  $('#batchcol .simpleTaxonSelector').each(function() {
    var taxon = $('#batchform .simpleTaxonSelector').data('taxon')
    $.fn.simpleTaxonSelector.selectTaxon(this, taxon)
  })
}

function batchObservationFields() {
  var fields = $('#batchform .observation_field')
  $('#batchcol .observation_fields').each(function() {
    var container = this,
        currentFields = $('.observation_field', this)
    fields.each(function() {
      var newField = $(this).clone()
      var fieldId = $(newField).data('observation-field-id')
      var existing = $('[data-observation-field-id='+fieldId+']', container).get(0)
      if (!existing) {
        $(container).append(newField)
        newField.removeClass('fieldified');
        ObservationFields.fieldify({focus: false})
        existing = newField
      }
      var val = $('.ofv_value_field', this).val()
      $('.ofv_value_field', existing).val(val)
      $('select', existing).val(val)
      // Bending over backward to set the taxon. Ignoring date and time selectors, people can just edit those by hand
      var autocompelteItem = $('.ui-autocomplete-input', this).data('autocomplete-item');
      if (autocompelteItem) {
        $('.ui-autocomplete-input', existing ).trigger( "assignSelection", autocompelteItem )
      }
    })

    var obsIndex = $(this).parents('.observation:first').find('.observed_on_string').attr('id').split('_')[1]
    $(':input', this).each(function() {
      if ($(this).attr('id')) {
        $(this).attr('id', $(this).attr('id').replace(/\d+_value/, obsIndex+'_value'))
      }
      if ($(this).attr('name')) {
        $(this).attr('name', $(this).attr('name').replace(/observation\[/, 'observations['+obsIndex+']['))
      }
    })
  })
}

$(document).ready(function() {
  $('.observation_fields_form_fields').observationFieldsForm()
  $.fn.soundSelector.bindMaxFileSizeValidation( $( ".observation_sounds" ) );
})
