$(document).ready(function() {  
  $('#observedchart').parent().hide()
  $('#filters select[multiple]').multiselect({
    header: false,
    noneSelectedText: "Colors",
    minWidth: 130,
    selectedText: function(selected, total, elts) {
      if (selected > 2) {
        return '<strong>'+selected+' colors</strong>'
      }
      var html = ''
      for (var i=0; i < elts.length; i++) {
        html += '<span class="colorfield '+elts[i].value+'">'+elts[i].value+'</span>'
      }
      return html
    }
  })
  $('#filters .establishmentfilter select').multiselect({
    header: false,
    noneSelectedText: "Native/endemic/inroduced",
    minWidth: 110,
    multiple: false,
    selectedText: function(selected, total, elts) {
      if (elts[0].value) {
        return "<strong>"+elts[0].title+"</strong>"
      } else {
        return elts[0].title
      }
    }
  })
  $('#filters .conservationfilter select').multiselect({
    header: false,
    noneSelectedText: "Conservation status",
    minWidth: 140,
    multiple: false,
    selectedText: function(selected, total, elts) {
      if (elts[0].value) {
        return "<strong>"+elts[0].title+"</strong>"
      } else {
        return elts[0].title
      }
    }
  })
  
  $('#filters select').siblings('input.button').hide()
  $('#filters select').change(function() {
    $(this).parents('form:first').submit()
  })
  
  $('#placephotos').loadFlickrPlacePhotos()
  PlaceGuide.init('#taxa')
  $('#maintabs').tabs({
    show: function(event, ui) {
      if ($(ui.panel).attr('id') == 'abouttab' && !$(ui.panel).hasClass('loaded')) {
        $('#abouttab .photos').loadFlickrPlacePhotos({urlType: 'url_m', showAttribution: true, noPhotosNotice: true})
        $('#abouttab .wikipedia_description').loadWikipediaDescription()
        $(ui.panel).addClass('loaded')
      }
    },
    load: function(event, ui) {
      if ($(ui.panel).hasClass('observations')) {
        if ($(ui.panel).text() == '') {
          $(ui.panel).append(
            $('<span>No observations from this place yet.</span>').addClass('noresults meta')
          )
        } else {
          $(ui.panel).append(
            $('<div></div>').addClass('morelink').append(
              $('<a>View more</a>').addClass('readmore').attr('href', $(ui.tab).attr('rel'))
            )
          )
        }
      }
    }
  })
})

$.fn.loadFlickrPlacePhotos = function(options) {
  options = $.extend({}, {
    urlType: 'url_t'
  }, options)
  var extras = ['owner_name', 'date_upload']
  extras.push(options.urlType)
  extras = extras.join(',')
  var self = this
  var flickrOptions = {
    api_key: FLICKR_API_KEY,
    sort: 'interestingness-desc',
    page: 1,
    per_page: 7,
    extras: extras,
    safe_search: 1,
    text: "landscape -portrait -model -birthday -honeymoon -festival -halloween -iPad",
    license: '1,2,3,4,5,6'
  }
  
  if (PLACE.woeid && PLACE.woeid != '') {
    flickrOptions.woe_id = PLACE.woeid
  } else if (PLACE.swlng) {
    flickrOptions.bbox = [PLACE.swlng, PLACE.swlat, PLACE.nelng, PLACE.nelat].join(', ')
  } else {
    flickrOptions.lat = PLACE.latitude
    flickrOptions.lon = PLACE.longitude
  }
  
  $.getJSON(
    "http://www.flickr.com/services/rest/?method=flickr.photos.search&format=json&jsoncallback=?",
    flickrOptions,
    function(json) {
      $(self).html('')
      if (json.photos && json.photos.photo && json.photos.photo.length > 0) {
        for (var i = json.photos.photo.length - 1; i >= 0; i--){
          var p = json.photos.photo[i],
              date = new Date(p.dateupload * 1000),
              attribution = ("(CC) " + (date.getFullYear() || '') + " " + p.ownername).replace(/\s+/, ' '),
              url = 'http://www.flickr.com/photos/'+p.owner+'/'+p.id
          $(self).append(
            $('<a href="'+url+'"></a>').append(
              $('<img></img>')
                .attr('src', p[options.urlType]).attr('title', attribution)
            )
          )
          if (options.showAttribution) {
            $(self).append($('<div class="stacked attribution meta"></div>').html('Photo: '+attribution))
          }
        }
      } else if (options.noPhotosNotice) {
        $(self).append('<div class="noresults meta">Flickr has no Creative Commons-licensed photos from this place.</div>')
      }
    }
  )
}

$.fn.loadWikipediaDescription = function() {
  var self = this
  $.ajax({
    url: WIKIPEDIA_DESCRIPTION_URL,
    method: 'get',
    success: function(data, status) {
      $(self).html(data)
    },
    error: function(request, status, error) {
      $('.noresults', self).show()
      $('.loading', self).hide()
    }
  })
}

var PlaceGuide = {
  IGNORE_PARAMS: ['test', 
    'size',
    'grid',
    'labeled',
    'bgcolor',
    'multiselect_colorsFilter', 
    'multiselect_colorsFilter[]', 
    'multiselect_conservationFilter', 
    'multiselect_establishmentFilter'],
  OVERRIDE_EXISTING: 0,
  RESPECT_EXISTING: 1,
  REPLACE_EXISTING: 2,
  
  cleanParamString: function(s) {
    var re
    for (var i = PlaceGuide.IGNORE_PARAMS.length - 1; i >= 0; i--){
      re = new RegExp(PlaceGuide.IGNORE_PARAMS[i]+'=[^\&]*\&?', 'g')
      s = s.replace(re, '')
    }
    return s
  },
  
  init: function(context) {
    window.taxa = window.taxa || {}
    // ensure controls change url state
    function replaceParams() {
      var href = $(this).attr("href") || $(this).serialize()
      href = PlaceGuide.cleanParamString(href)
      var state = href.match(/[\?\&=]/) ? $.deparam.querystring(href) : {}
      $.bbq.pushState(state, PlaceGuide.REPLACE_EXISTING)
      return false
    }
    function filterParams() {
      var href = $(this).attr("href") || $(this).serialize()
      href = PlaceGuide.cleanParamString(href)
      $.bbq.pushState($.deparam.querystring(href))
      return false
    }
    function underrideParams() {
      var href = $(this).attr("href") || $(this).serialize()
      href = PlaceGuide.cleanParamString(href)
      $.bbq.pushState($.deparam.querystring(href), PlaceGuide.RESPECT_EXISTING)
      return false
    }
    $('#browsingtaxa a, #controls form.searchfilter a').click(replaceParams)
    $('#controls form').each(function() {
      if ($(this).hasClass('searchfilter')) {
        $(this).submit(replaceParams)
      } else {
        $(this).submit(filterParams)
      }
    })
    $('#controls form.colorfilter a').click(function() {
      $.bbq.removeState('colors')
      return false
    })
    
    $('#controls form.establishmentfilter a').click(function() {
      $.bbq.removeState('establishment_means')
      return false
    })
    
    $('#controls form.conservationfilter a').click(function() {
      $.bbq.removeState('conservation_status')
      return false
    })
    
    // ensure url state changes update controls
    $(window).bind("hashchange", function(e) {
      var taxon = $.bbq.getState('taxon')
      $('#browsingtaxa a').removeClass('selected')
      if (taxon) {
        $('#browsingtaxa a.taxon_'+taxon).addClass('selected')
      } else {
        $('#browsingtaxa a.default_taxon').addClass('selected')
      }
      $('#controls form.searchfilter input[type=text]').val($.bbq.getState('q'))
      $('#controls form.colorfilter select').val($.bbq.getState('colors'))
      $('#controls form.establishmentfilter select').val($.bbq.getState('establishment_means'))
      $('#controls form.conservationfilter select').val($.bbq.getState('conservation_status'))
      $('#controls select:hidden').multiselect('refresh')
      if ($.bbq.getState('colors')) {
        $('#controls form.colorfilter .pale.button').show()
      } else {
        $('#controls form.colorfilter .pale.button').hide()
      }
      if ($.bbq.getState('establishment_means')) {
        $('#controls form.establishmentfilter .pale.button').show()
      } else {
        $('#controls form.establishmentfilter .pale.button').hide()
      }
      if ($.bbq.getState('conservation_status')) {
        $('#controls form.conservationfilter .pale.button').show()
      } else {
        $('#controls form.conservationfilter .pale.button').hide()
      }
      
      if ($.bbq.getState('q')) {
        $('#controls form.searchfilter .pale.button').show()
      } else {
        $('#controls form.searchfilter .pale.button').hide()
      }
      
      // updated observed link
      $('#sidecol .extralabel a').querystring($.bbq.getState(), PlaceGuide.REPLACE_EXISTING)
    })
    
    $(window).bind("hashchange", function(e) {
      PlaceGuide.load(context)
    })
    if ($('.listed_taxon', context).length > 0) {
      PlaceGuide.ajaxify(context)
    }
    var cleanQueryString = PlaceGuide.cleanParamString($.param.querystring())
    if (cleanQueryString != '' && $.param.fragment() == '') {
      $.bbq.pushState(cleanQueryString)
    } else if ($('.listed_taxon', context).length == 0) {
      $(window).trigger('hashchange')
    }
  },
  load: function(context, options) {
    $(context).shades('open', {
      css: {'background-color': 'white'}, 
      content: '<center style="margin: 100px;"><span class="loading bigloading status inlineblock">Loading...</span></center>'
    })
    var options = options || {}
    var url = options.url || $(context).attr('data-guide-url')
    if (!url) {
      pieces = window.location.pathname.split('/')
      placeId = pieces[pieces.length-1]
      url = window.location.origin + '/places/guide/'+placeId
    }
    var data = $.param.fragment()
    if (data.length == 0) {
      url = url.replace('guide', 'cached_guide')
    }
    if (PlaceGuide.lastRequest) {
      PlaceGuide.lastRequest.abort()
    }
    PlaceGuide.lastRequest = $.ajax({
      url: url,
      type: 'GET',
      data: data,
      dataType: 'html'
    }).done(function(html) {
      $('#taxa .guide_taxa').infinitescroll('destroy')
      $(context).html(html)
      PlaceGuide.lastRequest = null
      PlaceGuide.ajaxify(context)
      if ($('#taxa .guide_taxa .pagination').length > 0) {
        $('#taxa .guide_taxa').infinitescroll({
          navSelector  : ".pagination",
          nextSelector : ".pagination .next_page",
          itemSelector : ".guide_taxa .listed_taxon",
          bufferPx: 1000,
          loading: {
            img: '/images/spinner-small.gif',
            msgText: '',
            finishedMsg: '<span class="meta">No more taxa to load!</span>'
          }
        }, function() {
          PlaceGuide.ajaxify(context)
        })
      }
    })
  },
  updateConfirmedChart: function(context) {
    PlaceGuide.updateBarchart(context, '#confirmedchart', 'data-confirmed-listed-taxa-count', {extraLabel: 'confirmed'})
  },
  updateObservedChart: function(context) {
    values = PlaceGuide.updateBarchart(context, '#observedchart', 'data-current-user-observed-count')
    if (!values) { 
      $('#observedchart').parent().hide()
      return
    }
    $('#sidecol .extralabel .value').text(values.valueWidth)
    $('#observedchart').parent().show()
  },
  updateBarchart: function(context, selector, countAttr, options) {
    options = options || {}
    var count = $('.guide_taxa', context).attr(countAttr)
    if (!count) { return false }
    var total = $('.guide_taxa', context).attr('data-listed-taxa-count') || $(selector).attr('data-original-total') || 0,
        labelText = ' of ' + total,
        valueWidth = Math.round(total == 0 ? 0 : (count / total)*100),
        remainderWidth = 100 - valueWidth,
        valueLabel = '',
        remainderLabel = ''
    if (options.extraLabel) { labelText += ' ' + options.extraLabel}
    if (valueWidth > 10) {
      valueLabel += count
      if (remainderWidth < 50) {
        valueLabel += ' ' + labelText
      }
    } else {
      remainderLabel += count
    }
    if (remainderWidth >= 50) {
      remainderLabel += labelText
    }
    
    if (valueLabel.replace(/\s+/, '') == '') { valueLabel = "&nbsp;"}
    if (remainderLabel.replace(/\s+/, '') == '') { remainderLabel = "&nbsp;"}
    
    $('.value', selector).width((count / total)*100 + '%').find('.label').html(valueLabel)
    $('.remainder', selector).width(100-(count / total)*100 + '%').find('.label').html(remainderLabel)
    return {count: count, total: total, valueWidth: valueWidth}
  },
  ajaxify: function(context) {
    var jsonContainer = $(context).find('code.json')
    var newTaxa = $.parseJSON(jsonContainer.text())
    if (newTaxa) {
      window.taxa = $.extend({}, window.taxa, newTaxa)
    }
    jsonContainer.remove()
    
    PlaceGuide.updateConfirmedChart(context)
    PlaceGuide.updateObservedChart(context)
    $('[data-tip]', context).each(autoTip)
    $('.pagination a', context).click(function() {
      var href = $(this).attr("href")
      $.bbq.pushState($.deparam.querystring(href))
      return false
    })
    $('.listed_taxon', context).not('.ajaxified').each(function() {
      $(this).addClass('ajaxified')
      var matches = $(this).attr('href').match(/listed_taxa\/(\d+)/)
      if (!matches) { return }
      var listedTaxonId = matches[1]
      if (!listedTaxonId) { return }
      var dialogId = 'listed_taxon_dialog_'+listedTaxonId,
          dialog = $('#'+dialogId),
          taxonElt = $(this).find('.taxon[id*="taxon_"]').get(0),
          taxonId = taxonElt ? $(taxonElt).attr('id').split('_')[1] : null,
          taxon = window.taxa[taxonId]
      if (dialog.length == 0) {
        dialog = $('<div id="'+dialogId+'"></div>').addClass('dialog')
        $('body').append(dialog)
        dialog.hide()
      }
      var title = 'Taxon'
      if (taxon) {
        if (taxon.common_name) {
          title = taxon.common_name.name + ' (<i>'+taxon.name+'</i>)'
        } else {
          title = '<i>'+taxon.name+'</i>'
        }
      }
      title += ' in ' + PLACE.display_name
      $(dialog).dialog({
        autoOpen: false,
        width: '90%',
        title: title,
        
        // faking modal behavior to make sure google maps links are clickable
        open: function() {
          $(document.body).shades()
        },
        close: function(event, ui) {
          $(document.body).shades('close')
        }
      })
      $(this).click(function() {
        var dialog = $('#'+dialogId)
        $(dialog).dialog('open')
        if ($(dialog).html() == '') {
          $(dialog).append($('<span class="loading status">Loading...</span>'))
          $(dialog).load($(this).attr('href') + '?partial=guide', function(foo) {
            var dialog = $('#'+dialogId),
                newHeight = $(':first', dialog).height() + 60,
                maxHeight = $(window).height() * 0.8
            if (newHeight > maxHeight) { newHeight = maxHeight };
            $(this).dialog('option', 'height', newHeight)
            $(this).dialog('option', 'position', {my: 'center', at: 'center', of: $(window)})
            $('.map', this).taxonMap()
            $('.side .photos a', this).has('img').click(function() {
              $(this).parents('.listed_taxon_guide').find('.tabs').tabs('select', 1)
              $(this).parents('.dialog:first').scrollTo('.tabs a[href="'+$(this).attr('href')+'"] img')
              return false
            })
            
            if ($('.desc', this).width() < $('.side', this).width()) {
              $('.listed_taxon_guide', this).addClass('compact')
              google.maps.event.trigger($('.map', this).data('taxonMap'), 'resize')
            }
            
            $('.tabs', this).tabs({
              ajaxOptions: {
                data: "partial=cached_component"
              },
              load: function(event, ui) {
                if ($(ui.panel).text() == '') {
                  $(ui.panel).append(
                    $('<span>No observations from this place yet.</span>').addClass('noresults meta')
                  )
                } else {
                  $(ui.panel).append(
                    $('<a>View more</a>').addClass('readmore').attr('href', $(ui.tab).attr('rel'))
                  )
                }
              }
            })
          })
        }
        return false
      })
    })
  }
}
