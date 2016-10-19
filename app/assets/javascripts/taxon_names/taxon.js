function updatePositions(container, sortable) {
  $selection = $(sortable+':visible', container)
  $selection.each(function() {
    $('input[name*="position"]', this).val($selection.index(this))
    $('input[name*="position"]', this).parents('form:first').submit()
  })
}
$('ul.names').sortable({
  items: "> li",
  cursor: "move",
  placeholder: 'stacked sorttarget',
  update: function(event, ui) {
    updatePositions(this, "li")  
  }
})
