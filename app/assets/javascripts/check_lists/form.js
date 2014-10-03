$(document).ready(function() {
  $('#taxon_name').simpleTaxonSelector({
    taxonIDField: '#check_list_taxon_id',
    afterSelect: function afterSelect(wrapper, taxon, options) {
      $('#iconic_taxon_id').val('');
    }
  });
  
  // Make two taxon selectors clear their counterpart when selected
  $('#iconic_taxon_id').change(function() {
    $.fn.simpleTaxonSelector.unSelectTaxon($('.simpleTaxonSelector:first'));
  });
});
