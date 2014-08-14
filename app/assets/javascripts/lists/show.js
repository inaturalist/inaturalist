$(document).ready(function() {
  $('#new_listed_taxon').hide()
  
  // Set up the add batch dialog
  $('#add_batch_dialog').jqm({
    onShow: iNaturalist.modalShow,
    closeClass: 'close'
  })
  
  $('.actions .removelink').bind('ajax:before', function() {
    $(this).parents('.listed_taxon:first').fadeOut().parents('.listed_taxon_photo:first').fadeOut()
  })

  $('#taxonchooser').chooser({
    collectionUrl: '/taxa/autocomplete.json',
    resourceUrl: '/taxa/{{id}}.json?partial=chooser',
    afterSelect: function(taxon) {
      if (!FILTER_TAXON || FILTER_TAXON.id != taxon.id) {
        $('#taxonchooser').parents('form:first').submit()
      }
    }
  });

  $('.taxonchooser').chooser({
    collectionUrl: '/taxa/autocomplete.json',
    resourceUrl: '/taxa/{{id}}.json?partial=chooser'
  })
})
