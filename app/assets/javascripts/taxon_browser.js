var TaxonBrowser = {
  ajaxify: function(context) {
    var context = context || $('#taxon_browser')
    $('a[href^="/taxa/search"]', context).click(TaxonBrowser.handleSearchClicks);
    $('form.taxon_search_form', context).submit(TaxonBrowser.handleFormSubmits);
    TaxonBrowser.addTips();
    $('.loading:first', context).hide();
    $('#taxon_browser #taxon_list').shades('close')
  },
  
  addTips: function(context) {
    var context = context || $('#taxon_browser')
    $('.taxon_list_taxon > .taxon', context).each(TaxonBrowser.handleTaxonQtip);
  },

  handleFormSubmits: function(e) {
    TaxonBrowser.request($(this).attr('action'), $(this).serializeObject())
    return false;
  },

  handleSearchClicks: function(e) {
    TaxonBrowser.request($(this).attr('href'))
    return false
  },

  request: function(href, params) {
    $('#taxon_browser').parents('.dialog:first').scrollTo(0,0)

    $('#taxon_browser #taxon_list').shades('open', {
      css: {'background-color': 'white'}, 
      content: '<center style="margin: 100px;"><span class="loading bigloading status inlineblock">'+ I18n.t('loading') +'</span></center>'
    })

    var oldReq = $('#taxon_browser').data('lastRequest')
    if (oldReq) { oldReq.abort() }
    params = $.param($.extend({}, params, {
      partial: 'browse',
      authenticity_token: $('meta[name=csrf-token]').attr('content')
    }))
    var req = $.get(href, params, function(data, status) {
      $('#taxon_browser').html(data)
      TaxonBrowser.ajaxify()
    })
    $('#taxon_browser').data('lastRequest', req)
  },

  handleTaxonQtip: function() {
    $(this).qtip($.extend(QTIP_DEFAULTS, {
      content: {text: this.innerHTML}
    }));
  }
}
