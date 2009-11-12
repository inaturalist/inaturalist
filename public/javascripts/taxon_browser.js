var TaxonBrowser = {
  ajaxify: function() {
    $('#taxon_browser a[href^=/taxa/search]').click(TaxonBrowser.handleSearchClicks);
    $('#taxon_browser .taxa > .taxon').each(TaxonBrowser.handleTaxonQtip);
    $('#taxon_browser form').submit(TaxonBrowser.handleFormSubmits);
    $('#taxon_browser .loading').hide();
  },

  handleFormSubmits: function(e) {
    $('#taxon_browser .loading').show();
    $('#taxon_browser').load($(this).attr('action'), $(this).serialize()+'&partial=browse', TaxonBrowser.ajaxify);
    return false;
  },

  handleSearchClicks: function(e) {
    $('#taxon_browser .loading').show();
    // don't make the extra params an object literal.  That will force a POST 
    // request, which will screw up the pagination links
    $('#taxon_browser').load($(this).attr('href'), "partial=browse", TaxonBrowser.ajaxify);
    return false;
  },

  handleTaxonQtip: function() {
    $(this).qtip($.extend(QTIP_DEFAULTS, {
      content: {text: this.innerHTML}
    }));
  }
}
