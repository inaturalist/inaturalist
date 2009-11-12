$(document).ready(function() {
  $('.species_guess').simpleTaxonSelector();
  $('.observed_on_string').iNatDatepicker();
  $('.place_guess').latLonSelector({
    mapDiv: $('#mapcontainer').get(0),
    map: iNaturalist.Map.createMap({div: $('#mapcontainer').get(0)})
  });
  $('.observation_photos').each(function() {
    // The photo_fields endpoint needs to know the auth token and the index
    // for the field
    var index_str = $(this).parents('.observation:first').find('input:visible:first').attr('name');
    var index = $.string(index_str).gsub(/[^\d]*/, '').str;
    var authenticity_token = $(this).parents('form').find(
      'input[name=authenticity_token]').val();
    $(this).photoSelector({
      baseURL: '/flickr/photo_fields?context=user',
      urlParams: {
        authenticity_token: authenticity_token,
        index: index,
        limit: 12
      }
    });
  });
  
  // Setup taxon browser
  $('body').append(
    $('<div id="taxonchooser" class="modalbox dialog"></div>').append(
      $('<div id="taxon_browser"></div>').append(
        $('<div class="loading status">Loading...</div>')
      )
    ).hide()
  );
  
  $('#taxonchooser').jqm({
    onShow: function(h) {
      h.w.fadeIn(500);
      if (h.w.find('#taxon_browser > .loading').length == 1) {
        h.w.find('#taxon_browser').load(
          '/taxa/search?partial=browse&js_link=true',
          {}, TaxonBrowser.ajaxify);
      }
    }
  });
});

function handleTaxonClick(e, taxon) {
  $.fn.simpleTaxonSelector.selectTaxon($('.simpleTaxonSelector:first'), taxon);
  $('#taxonchooser').jqmHide();
}
