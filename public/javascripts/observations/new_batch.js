$(document).ready(function() {
  $('.species_guess').simpleTaxonSelector();
  $('.observed_on_string').iNatDatepicker();
  $('.place_guess').latLonSelector();
  $('#batchform').addClass('closed');
  $('#batch_form_fields').hide();
});
