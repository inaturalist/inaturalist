$(function() {
  $("#q").taxonAutocomplete({
    thumbnail: false,
    allow_placeholders: true,
    allow_enter_submit: true,
    afterSelect: function( ui ) {
      window.location.href = inaturalist.TAXON_ROOT_URL + ui.item.id;
    }
  });
});
