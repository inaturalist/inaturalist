$(document).ready(function() {
  $('#sidebar').fixedFollower();
  $('#new_listed_taxon').hide();
  
  // Set up the add batch dialog
  $('#add_batch_dialog').jqm({
    closeClass: 'close'
  });
});
