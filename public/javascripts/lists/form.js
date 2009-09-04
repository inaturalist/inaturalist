$(document).ready(function() {
  $('#taxon_input_1').simpleTaxonSelector();
  
  // Hide the type options initially
  $('#optionscol .type_fields').hide();
  
  // Toggle the list type options based on currently checked input
  $('#typescol input:checked').each(function() {
    $('#' + $(this).val().toLowerCase() + '_fields').show();
  });
  
  // Bind list type input to show list type options
  $('#typescol input').click(function() {
    $('#' + $(this).val().toLowerCase() + '_fields').toggle();
  });
});
