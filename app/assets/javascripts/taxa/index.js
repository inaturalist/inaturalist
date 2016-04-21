$(function() {
  $("#q").taxonAutocomplete({
    thumbnail: false,
    allowPlaceholders: true,
    allowEnterSubmit: true,
    searchExternal: false,
    afterSelect: function( ui ) {
      window.location.href = "/taxa/" + ui.item.id;
    }
  });
});
