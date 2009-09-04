$(document).ready(function() {
  // $('.compact_fieldset').compactFieldset();
  $('.species_guess').simpleTaxonSelector();
  $('.observed_on_string').iNatDatepicker();
  $('.place_guess').latLonSelector();
  $('.observation_photos').each(function() {
    // The photo_fields endpoint needs to know the auth token and the index
    // for the field
    var index_str = $(this).parents('.observation:first').find('input:visible:first').attr('name');
    var index = $.string(index_str).gsub(/[^\d]*/, '').str;
    var authenticity_token = $(this).parents('form').find(
      'input[name=authenticity_token]').val();
    $(this).photoSelector({
      baseURL: '/flickr/photo_fields?context=user',
      urlParams: {
        authenticity_token: authenticity_token,
        index: index,
        limit: 16
      }
    });
  });
  $('#batchform').addClass('closed');
  $('#batch_form_fields').hide();
});
