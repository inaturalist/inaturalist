$(document).ready(function() {
  $('#user_prefers_no_email').click(function() {
    $('#notificationpreferences input').attr('checked', !$(this).attr('checked'))
  })
  $('#notificationpreferences input').click(function() {
    $('#user_prefers_no_email').attr('checked', false)
  })
  $('.placechooser').chooser({
    collectionUrl: '/places/autocomplete.json',
    resourceUrl: '/places/{{id}}.json?partial=autocomplete_item'
  })
})
