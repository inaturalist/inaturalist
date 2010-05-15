var TaxonBrowser = {
  ajaxify: function() {
    $('#taxon_browser a[href^=/taxa/search]').click(TaxonBrowser.handleSearchClicks);
    $('#taxon_browser form').submit(TaxonBrowser.handleFormSubmits);
    TaxonBrowser.addTips();
    $('#taxon_browser .loading').hide();
  },
  
  addTips: function() {
    $('#taxon_browser .taxon_list_taxon > .taxon').each(TaxonBrowser.handleTaxonQtip);
  },

  handleFormSubmits: function(e) {
    $('#taxon_browser .loading').show();
    var params = $(this).serialize()+'&partial=browse';
    $.get($(this).attr('action'), params, function(data, status) {
      $('#taxon_browser').html(data);
      TaxonBrowser.ajaxify();
    });
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
