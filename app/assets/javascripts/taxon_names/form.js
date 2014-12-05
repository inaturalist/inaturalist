$('#place_taxon_names').bind('cocoon:after-insert', function(e, inserted_item) {
  $('.placechooser', inserted_item).chooser({
    collectionUrl: '/places/autocomplete.json',
    resourceUrl: '/places/{{id}}.json?partial=autocomplete_item'
  })
})
$('.placechooser').chooser({
  collectionUrl: '/places/autocomplete.json',
  resourceUrl: '/places/{{id}}.json?partial=autocomplete_item'
})
