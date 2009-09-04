// Returns the index of the last fieldset currently in the interface.
window.getLastFieldsetIndex = function() {
 return parseInt($$('fieldset.new_observation').pop().id.split('_').pop());
}

// Returns the index of the next, hypothetical fieldset in the interface.
window.getNextFieldsetIndex = function() {
 return (getLastFieldsetIndex() + 1);
}

// Updates the most recently added fieldset to include an interactive map.
window.updateNewlyAddedFieldset = function() {
  var fieldset = $$('fieldset.new_observation').pop();
  var fieldset_index = getLastFieldsetIndex();
  
  var remove_link = new Element('a', {
    title: 'Click to remove this observation.'
  }).update('X');
  remove_link.setAttribute('class', 'remove_new_observation');
  remove_link.observe('click', function(event){
    Effect.Fade(this.parentNode, {duration: 0.2});
    Element.remove.delay(1, this.parentNode);
  });
  fieldset.insert({top: remove_link});
  
  var map = buildMap(fieldset);
  
  buildFlickrQuery(fieldset, fieldset_index);
  
  $('taxa_search_form_taxon_name-' + fieldset_index).focus();
  Effect.ScrollTo.delay(0.2, fieldset);
}

// Build a map for each form added.
window.buildMap = function(fieldset) {
  var map = iNaturalist.Map.createMap({
              div: fieldset.select('div.observation_map')[0],
              lat: 40.714,
              lng: -98.262,
              zoom: 3,
              controls: 'small'
            });

  var geocoder = new GClientGeocoder();

  fieldset.select('input[name="map_search_action"]')[0].observe('click', function(event){
    geocoder.setViewport(map.getBounds());
    geocoder.getLocations(fieldset.select('input[name="observation[place_guess]"]')[0].value, addressToMap);
  });
  
  // capture 'enter' commands and prevent them from submitting the form
  var map_search = fieldset.select('input[name="observation[place_guess]"]')[0];
  map_search.observe('keypress', function(event) {
    if (event.keyCode == 13) {
      fieldset.select('input[name="map_search_action"]')[0].click();
      Event.stop(event);
      return false;
    }
  });

  function addressToMap(response) {
    if (!response || response.Status.code != 200) {
      alert("Sorry, we were unable to locate that place.");
    } else {
      // zoom spans ~ 0 - 14;
      // accuracy spans 0 - 8;
      var zoom = (parseInt(response.Placemark[0].AddressDetails.Accuracy)*3)-1;
      zoom = zoom > 14 ? 14 : zoom;
      var place = response.Placemark[0];
      var point = new GLatLng(
        place.Point.coordinates[1],
        place.Point.coordinates[0]);
      map.setCenter(point,zoom);
      
      updateLatLngZoomFormElements(point, map, fieldset);
      
      var marker = map.addNewUnsavedMarker(point.lat(), point.lng(),
                    {draggable: true,
                     icon: iNaturalist.Map.createPlaceIcon({color: "DeepPink"})});
      
      GEvent.addListener(marker, 'dragstart', function() {
        marker.closeInfoWindow();
      });
      
      GEvent.addListener(marker, 'dragend', function() {
        updateLatLngZoomFormElements(marker.getLatLng(), map, fieldset);
        generateNewPointMarker(marker.getLatLng(), map, fieldset);
      });
    }
  }
  


  GEvent.addListener(map, 'click', function(overlay, point){
    updateLatLngZoomFormElements(point, map, fieldset);
    generateNewPointMarker(point, map, fieldset);
  });

  return map;
}

function generateNewPointMarker(point, map, fieldset) {
  var marker = map.addNewUnsavedMarker(point.lat(), point.lng(),
                {draggable: true,
                 icon: iNaturalist.Map.createObservationIcon({color: "DeepPink"})});

  GEvent.addListener(marker, 'dragstart', function() {
    marker.closeInfoWindow();
  });

  GEvent.addListener(marker, 'dragend', function() {
    updateLatLngZoomFormElements(marker.getLatLng(), map, fieldset);
  });
}

function updateLatLngZoomFormElements(point, map, fieldset) {
  fieldset.select('input[name="observation[latitude]"]')[0].value = point.lat();
  fieldset.select('input[name="observation[longitude]"]')[0].value = point.lng();
  fieldset.select('input[name="observation[map_scale]"]')[0].value = map.getZoom();
}

function buildFlickrQuery(fieldset, fieldset_index) {
  var input   = fieldset.select('input.flickr_photo_search_input').pop();
  var button  = fieldset.select('input.flickr_search_button').pop();
  var status  = fieldset.select('div.flickr_photo_status').pop();
  var display = fieldset.select('div.flickr_photo_display').pop();
  
  if (typeof(button) != 'undefined') {
    button.observe('click', function(event){
      window.queryPhotos(input.value, fieldset_index, status);
      Event.stop(event);
      return false;
    });

    input.observe('keypress', function(event) {
      if (event.keyCode == 13) {
        button.click();
        Event.stop(event);
        return false;
      }
    });
  };
}

window.queryPhotos = function(text, index, status) {
  var uri = '/flickr/photos.js?';
  uri = text ? uri + 'q=' + encodeURIComponent(text) : uri;
  uri = index ? uri + '&i=' + encodeURIComponent(index) : uri;
  // console.log(uri);
  new Ajax.Request(uri, {
    method: 'get',
    onCreate: function(transport) {
      status.toggle();
      status.update('Loading...');
      status.addClassName('loading');
    },
    onComplete: function(transport) {
      status.removeClassName('loading');
    },
    onSuccess: function(transport) {
      status.toggle();
      status.update('');
    },
    onFailure: function(transport) {
      status.addClassName('error');
      status.update(
        "Arg, something went wrong connecting to Flickr. "+
        "If you <a href='http://groups.google.com/group/inaturalist'>"+
        "let us know</a> how this happened, hopefully we'll be able " +
        "to fix it.");
    }
  });
}
