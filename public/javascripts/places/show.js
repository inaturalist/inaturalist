$(document).ready(function() {  
  // Load wikipedia desc
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
  // console.log("flickrOptions: ", flickrOptions);
  $.getJSON(
    "http://www.flickr.com/services/rest/?method=flickr.photos.search&format=json&jsoncallback=?",
    flickrOptions,
    function(json) {
      // console.log("json: ", json);
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
  );
})
