$(document).ready(function() {  
  $('#filters select[multiple]').multiselect({
    header: false,
    noneSelectedText: "Select colors",
    minWidth: 130,
    selectedText: function(selected, total, elts) {
      if (selected > 2) {
        return selected+' colors'
      }
      var html = ''
      for (var i=0; i < elts.length; i++) {
        html += '<span class="colorfield '+elts[i].value+'">'+elts[i].value+'</span>'
      }
      return html
    }
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
    text: "landscape -portrait -model",
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
  IGNORE_PARAMS: ['test', 'multiselect_colorsFilter', 'multiselect_colorsFilter[]'],
  OVERRIDE_EXISTING: 0,
  RESPECT_EXISTING: 1,
  REPLACE_EXISTING: 2,
  
  cleanParamString: function(s) {
    var re
    for (var i = PlaceGuide.IGNORE_PARAMS.length - 1; i >= 0; i--){
      re = new RegExp(PlaceGuide.IGNORE_PARAMS[i]+'=[^\&]*', 'g')
      s = s.replace(re, '')
    }
    return s
  },
  
  init: function(context) {
    // ensure controls change url state
    function replaceParams() {
      var href = $(this).attr("href") || $(this).serialize()
      href = PlaceGuide.cleanParamString(href)
      $.bbq.pushState($.deparam.querystring(href), PlaceGuide.REPLACE_EXISTING)
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
    $('#controls form.searchfilter').submit(replaceParams)
    $('#controls form.colorfilter').submit(filterParams)
    $('#controls form.colorfilter a').click(function() {
      $.bbq.removeState('colors')
      return false
    })
    
    // ensure url state changes update controls
    $(window).bind("hashchange", function(e) {
      var taxon = $.bbq.getState('taxon')
      $('#browsingtaxa a').removeClass('selected')
      if (taxon) {
        $('#browsingtaxa a.taxon_'+taxon).addClass('selected')
      }
      $('#controls form.searchfilter input[type=text]').val($.bbq.getState('q'))
      $('#controls form.colorfilter select').val($.bbq.getState('colors'))
      $('#controls form.colorfilter select').multiselect('refresh')
      if ($.bbq.getState('colors')) {
        $('#controls form.colorfilter .pale.button').show()
      } else {
        $('#controls form.colorfilter .pale.button').hide()
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
      content: '<div class="noresults"><span class="loading bigloading status inlineblock">Loading...</span></div>'
    })
    var options = options || {}
    var url = options.url || $(context).attr('data-guide-url')
    if (!url) {
      pieces = window.location.pathname.split('/')
      placeId = pieces[pieces.length-1]
      url = window.location.origin + '/places/guide/'+placeId
    }
    var data = $.param.fragment()
    $(context).load(url, data, function() {
      PlaceGuide.ajaxify(context)
      if ($('#taxa .guide_taxa .pagination').length > 0) {
        $('#taxa .guide_taxa').infinitescroll({
          navSelector  : ".pagination",
          nextSelector : ".pagination .next_page",
          itemSelector : ".guide_taxa .listed_taxon",
          bufferPx: 400,
          loading: {
            img: (window.location.origin + '/images/spinner-small.gif'),
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
    if (!values) { return }
    $('#sidecol .extralabel .value').text(values.valueWidth)
  },
  updateBarchart: function(context, selector, countAttr, options) {
    options = options || {}
    var count = $('.guide_taxa', context).attr(countAttr)
    if (!count) { return false }
    var total = $('.guide_taxa', context).attr('data-listed-taxa-count') || 0,
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
          taxon = taxa[taxonId]
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
        width: '80%',
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
