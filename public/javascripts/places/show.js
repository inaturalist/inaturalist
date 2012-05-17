$(document).ready(function() {  
  $('#placephotos').loadFlickrPlacePhotos()
  TaxonGuide.init('#taxa', {cached_guide: true})
  
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
