var TaxonBrowser = {
  ajaxify: function(context) {
    var context = context || $('#taxon_browser')
    $('a[href^="/taxa/search"]', context).click(TaxonBrowser.handleSearchClicks);
    $('form.taxon_search_form', context).submit(TaxonBrowser.handleFormSubmits);
    TaxonBrowser.addTips();
    $('.loading:first', context).hide();
  },
  
  addTips: function(context) {
    var context = context || $('#taxon_browser')
    $('.taxon_list_taxon > .taxon', context).each(TaxonBrowser.handleTaxonQtip);
  },

  handleFormSubmits: function(e) {
    $('#taxon_browser .loading:first').show();
    var params = $(this).serialize()+'&partial=browse';
    $.get($(this).attr('action'), params, function(data, status) {
      $('#taxon_browser').html(data);
      TaxonBrowser.ajaxify();
    });
    return false;
  },

  handleSearchClicks: function(e) {
    $('#taxon_browser .loading:first').show();
    // don't make the extra params an object literal.  That will force a POST 
    // request, which will screw up the pagination links
    $('#taxon_browser').load($(this).attr('href'), {partial: 'browse', js_link: true}, function() {TaxonBrowser.ajaxify()});
    return false;
  },

  handleTaxonQtip: function() {
    $(this).qtip($.extend(QTIP_DEFAULTS, {
      content: {text: this.innerHTML}
    }));
  }
}
