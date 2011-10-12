$(document).ready(function() {  
  // loadWikipediaDescription()
  loadFlickrPlacePhotos()
  PlaceGuide.ajaxify('#taxa')
})

function loadFlickrPlacePhotos() {
  var flickrOptions = {
    api_key: FLICKR_API_KEY,
    sort: 'interestingness-desc',
    page: 1,
    per_page: 7,
    woe_id: PLACE.woeid,
    extras: 'url_t,owner_name,date_upload',
    safe_search: 1,
    text: "landscape -portrait -model",
    license: '1,2,3,4,5,6'
  }
  
  if (PLACE.swlng) {
    flickrOptions.bbox = [PLACE.swlng, PLACE.swlat, PLACE.nelng, PLACE.nelat].join(', ')
  } else {
    flickrOptions.lat = PLACE.latitude
    flickrOptions.lon = PLACE.longitude
  }
  
  $.getJSON(
    "http://www.flickr.com/services/rest/?method=flickr.photos.search&format=json&jsoncallback=?",
    flickrOptions,
    function(json) {
      if (json.photos && json.photos.photo) {
        for (var i = json.photos.photo.length - 1; i >= 0; i--){
          var p = json.photos.photo[i],
              date = new Date(p.dateupload * 1000),
              attribution = ("(CC) " + (date.getFullYear() || '') + " " + p.ownername).replace(/\s+/, ' ')
          $('#placephotos').append(
            $('<a href="http://www.flickr.com/photos/'+p.owner+'/'+p.id+'"></a>').append(
              $('<img></img>')
                .attr('src', p.url_t).attr('title', attribution)
            )
          )
        }
      }
    }
  )
}

function loadWikipediaDescription() {
  $.ajax({
    url: WIKIPEDIA_DESCRIPTION_URL,
    method: 'get',
    success: function(data, status) {
      $('#wikipedia_description').html(data)
    },
    error: function(request, status, error) {
      $('#nodescription').show()
      $('#wikipedia_description .loading').hide()
    }
  })
}

var PlaceGuide = {
  ajaxify: function(context) {
    $('a[href*="listed_taxa"]', context).each(function() {
      var matches = $(this).attr('href').match(/listed_taxa\/(\d+)/)
      if (!matches) { return }
      var listedTaxonId = matches[1]
      if (!listedTaxonId) { return }
      var dialogId = 'listed_taxon_dialog_'+listedTaxonId,
          dialog = $('#'+dialogId),
          taxonElt = $(this).parents('.taxon[id*="taxon_"]').get(0),
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
        modal: true,
        title: title
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
          })
        }
        return false
      })
    })
  }
}