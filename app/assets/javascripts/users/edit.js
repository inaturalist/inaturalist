$(document).ready(function() {
  $('#user_prefers_no_email').click( function() {
    $('#notificationpreferences input').prop('checked', !$(this).prop('checked'))
  } );
  $('#notificationpreferences input').click( function() {
    $('#user_prefers_no_email').prop('checked', false)
  } );
  $('.placechooser').chooser( {
    collectionUrl: '/places/autocomplete.json',
    resourceUrl: '/places/{{id}}.json?partial=autocomplete_item'
  } );
  $('#user_block_blocked_user_id').chooser({
    queryParam: 'q',
    collectionUrl: '/people/search.json',
    resourceUrl: '/people/{{id}}.json'
  } );
})
