$(document).ready(function() {
  $('.species_guess').simpleTaxonSelector();
  $('.observed_on_string').iNatDatepicker();
  $('.place_guess').latLonSelector({
    mapDiv: $('#mapcontainer').get(0),
    map: iNaturalist.Map.createMap({div: $('#mapcontainer').get(0)})
  });
  
  // Setup taxon browser
  $('body').append(
    $('<div id="taxonchooser" class="clear modalbox dialog"></div>').append(
      $('<div id="taxon_browser" class="clear"></div>').append(
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
          {}, function() {TaxonBrowser.ajaxify()});
      }
    }
  });
});

function handleTaxonClick(e, taxon) {
  $.fn.simpleTaxonSelector.selectTaxon($('.simpleTaxonSelector:first'), taxon);
  $('#taxonchooser').jqmHide();
}

function afterFindPlaces() {
  TaxonBrowser.ajaxify('#find_places')
}
