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
