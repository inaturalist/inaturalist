$(document).ready(function() {
  $('#sidebar').fixedFollower()
  $('#new_listed_taxon').hide()
  
  // Set up the add batch dialog
  $('#add_batch_dialog').jqm({
    onShow: iNaturalist.modalShow,
    closeClass: 'close'
  })
  
  $('.actions .removelink').bind('ajax:before', function() {
    $(this).parents('.listed_taxon:first').fadeOut().parents('.listed_taxon_photo:first').fadeOut()
  })
})
