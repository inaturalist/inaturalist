function applyBatch(inputNames) {
  $.each(inputNames, function() {
    var batchVal = $('#batchform :input[name="observation['+this+']"]').val()
    if ($.trim(batchVal) != '') {
      $('#batchcol :input[name*="['+this+']"]').val(batchVal)
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
        existing = newField
      }
      var val = $('.ofv_value_field', this).val()
      $('.ofv_value_field', existing).val(val)
      $('select', existing).val(val)
    })

    var index = $(this).parents('.observation:first').attr('id').split('-')[1]
    $(':input', this).each(function() {
      if ($(this).attr('id')) {
        $(this).attr('id', $(this).attr('id').replace(/\d+_value/, index+'_value'))
      }
      if ($(this).attr('name')) {
        $(this).attr('name', $(this).attr('name').replace(/observation\[/, 'observations['+index+']['))
      }
    })
  })
}

$(document).ready(function() {
  $('.observation_fields_form_fields').observationFieldsForm()
})
