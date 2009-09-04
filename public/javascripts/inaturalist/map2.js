(function(){
/**
 * iNaturalist map object
 * Copyright (c) iNaturalist, 2007-2008
 * 
 * @created: 2008-01-01
 * @updated: 2008-04-12
 * @author: n8agrin
 * @author: kueda
 */

// requires GoogleMap classes
if (typeof(GBrowserIsCompatible) != 'function')
 throw "The Google map libraries must be loaded to use the iNaturalist Map " +
       "extensions.";

// extend parts of the Google Marker class
GMarker.prototype.observation_id = null;

// A map consists of the map itself, plus methods on how to add Observations
// javascript objects to the map and handle the updating of those objects
// when an Observation is moved or editted.

// storage for marker objects indexed by their corresponding
// observation_id's
GMap2.prototype.observations = {};
GMap2.prototype.places = {};
    
// used when creating observations from the map
// TODO: make this more like a stack to help with handling multiple
// unsaved markers
GMap2.prototype.lastUnsavedMarker = null;


GMap2.prototype.createMarker = function(lat, lng, options) {
  return new GMarker(new GLatLng(lat, lng), options);
};
  
// remove a single marker
GMap2.prototype.removeMarker = function(marker) {
  // gracefully clear the listeners out of memory
  GEvent.clearInstanceListeners(marker);
  
  // remove the marker from the map
  this.removeOverlay(marker);
};
  
GMap2.prototype.addNewCenteredMarker = function(options) {
  return this.addNewUnsavedMarker(this.getCenter().lat(),
                                  this.getCenter().lng(),
                                  options);
};
  
GMap2.prototype.addNewUnsavedMarker = function(lat, lng, options) {
  this.removeLastUnsavedMarker();
  this.lastUnsavedMarker = this.createMarker(lat, lng, options);
  this.addOverlay(this.lastUnsavedMarker);
  return this.lastUnsavedMarker;
};
  
  // Call this to remove the marker object from the lastUnsavedMarker value in the
  // iNaturalist.Map object.  This is usually used when canceling input into
  // a form, or when the lastUnsavedMarker object needs to be cleared out.
GMap2.prototype.removeLastUnsavedMarker = function() {
  if (this.lastUnsavedMarker) {
    this.removeMarker(this.lastUnsavedMarker);
    this.lastUnsavedMarker = null;
    return true;
  }
  return false;
};
  
// addObservation adds the observation to the map and tacks a marker
// obejct onto the Observation object.  This assumes the observation has
// already been saved.  Use addUnsavedMarker above if you need to add
// a single marker to the map in an unsaved state.
GMap2.prototype.addObservation = function(observation, options) {
  if (typeof(options) == 'undefined') { var options = {} };
  
  // Can't add an obs w/o coordinates
  if (typeof(observation.latitude) == 'undefined' || 
      typeof(observation.longitude) == 'undefined' ||
      observation.latitude == null || 
      observation.longitude == null) return false;

  if (typeof(options.icon) == 'undefined') {
    options.icon = iNaturalist.Map.createObservationIcon({
      observation: observation});
  }
  
  var marker = this.createMarker(
    observation.latitude,
    observation.longitude, options);
  
  // store the marker for later use, or for easy removing
  this.observations[observation.id] = marker;
  
  // build a generic marker infowwindow
  if (typeof(options.clickable) == 'undefined' || options.clickable != false) {
    marker.message = this.buildObservationInfoWindow(observation);
    
    // add a click handler to the marker so that one can keep track of it.
    GEvent.addListener(marker, 'click', this.openInfoWindow)
  };
  
  var bounds = this.getObservationBounds();
  bounds.extend(new GLatLng(observation.latitude, observation.longitude));
  this.setObservationBounds(bounds);
  
  // add the marker to the map
  this.addOverlay(marker);
  observation.marker = marker;
  
  // return the observation for futher use
  return observation;
};
  
GMap2.prototype.removeObservation = function(observation) {
  this.removeMarker(this.observations[observation.id]);
  delete this.observations[observation.id];
};
  
GMap2.prototype.addObservations = function(observations, options) {
  var map = this;
  $.each(observations, function() {
    var success = map.addObservation(this, options);
  });
};
  
  // remove many observations from a list of observations
GMap2.prototype.removeObservations = function(observations) {
  var map = this;
  $.each(observations, function() {
    map.removeObservation(this);
  });
};

GMap2.prototype.getObservationBounds = function() {
  if (typeof(this.observationBounds) == 'undefined') {
    this.observationBounds = new GLatLngBounds();
  };
  return this.observationBounds;
};

GMap2.prototype.setObservationBounds = function(bounds) {
  this.observationBounds = bounds;
};

GMap2.prototype.zoomToObservations = function() {
  var bounds = this.getObservationBounds();
  this.setZoom(this.getBoundsZoomLevel(bounds));
  this.setCenter(bounds.getCenter());
};

GMap2.prototype.addPlace = function(place, options) {
  if (typeof(options) == 'undefined') { var options = {} };
  
  if (typeof(options.icon) == 'undefined') {
    options.icon = iNaturalist.Map.createPlaceIcon();
  };
  var marker = this.createMarker(place.latitude, place.longitude, options);
  
  this.places[place.id] = marker;
  
  // If this is the first, set the bounds to the extent of the place.
  var placesLength = 0;
  for(var key in this.places) placesLength += 1;

  if (placesLength == 1 && place.swlat != null && place.swlat != '') {
    var bounds = new GLatLngBounds(new GLatLng(place.swlat, place.swlng), 
      new GLatLng(place.nelat, place.nelng));
  }
  // Otherwise just extend the bounds
  else {
    var bounds = this.getPlaceBounds();
    bounds.extend(new GLatLng(place.latitude, place.longitude));
  }
  this.setPlaceBounds(bounds);
  
  // add the marker to the map
  this.addOverlay(marker);
  place.marker = marker;
  
  // return the place for futher use
  return place;
}
// 
// GMap2.prototype.addPlaces = function(places, options) {
//   var map = this;
//   $.each(places, function() {
//     var success = map.addPlace(this, options);
//   });
// }
GMap2.prototype.removePlace = function(place) {
  this.removeMarker(this.places[place.id]);
  delete this.places[place.id];
}
GMap2.prototype.removePlaces = function(places) {
  var map = this;
  if (typeof(places) == 'undefined') {
    $.each(map.places, function() {
      map.removeMarker(this);
      delete this;
    });
  } else {
    $.each(places, function() {
      map.removePlace(this);
    });
  }
  this.placeBounds = new GLatLngBounds();
}
GMap2.prototype.zoomToPlaces = function() {
  var bounds = this.getPlaceBounds();
  this.setZoom(this.getBoundsZoomLevel(bounds));
  this.setCenter(bounds.getCenter());
}
GMap2.prototype.getPlaceBounds = function() {
  if (typeof(this.placeBounds) == 'undefined') {
    this.placeBounds = new GLatLngBounds();
  };
  return this.placeBounds;
}
GMap2.prototype.setPlaceBounds = function(bounds) {
  this.placeBounds = bounds;
}
  
GMap2.prototype.openInfoWindow = function() {
  this.openInfoWindow(this.message);
};
  
GMap2.prototype.buildObservationInfoWindow = function(observation) {  
  // First see if we can find an observation component for this observation
  var existing = document.getElementById('observation-'+observation.id);
  if (typeof existing != 'undefined' && typeof jQuery != 'undefined') {
    var infowinobs = $(existing).clone().get(0);
    $(infowinobs).find('.details').show();
    var wrapper = $(
      '<div class="mini infowindow observations"></div>').append(infowinobs);
    return $(wrapper).get(0);
  };
  
  if (typeof(Prototype) == 'object') {
    var wrapper = new Element('div');
    var species_guess = new Element('h3').insert(
      new Element('a', {href: '/observations/'+observation.id}).insert(observation.species_guess));
    var user = new Element('p').insert(
      new Element('a', {href: '/observations/'+observation.user.login}).insert(observation.user.login));
    var description = new Element('p').insert(observation.description);
    wrapper.insert(species_guess);
    wrapper.insert(user);
    wrapper.insert(description);
  } else {
    var wrapper = $('<div></div>').append(
      $('<h3></h3>').append(
        $('<a href="/observations/'+observation.id+'"></a>').append(
          observation.species_guess
        )
      ),
      $('<p></p>').append(
        $('<a href="/people/'+observation.user.login+'"></a>').append(
          observation.user.login
        )
      ),
      $('<p class="description"></p>').append(
        observation.description
      )
    ).get(0);
  }
  
  // handle photos
  // not in yet...
  // if (observation.flickr_photos.length > 0) {}
  
  return wrapper;
};
  
// GMap2.prototype.bindHiddenFormElements = function(lat, lng, scale) {
//     
// }
//   
// GMap2.prototype.bindGeocodeTextField = function(element) {
//     
// }

if (typeof iNaturalist === 'undefined') {
  this.iNaturalist = {};
};

if (typeof iNaturalist.Map === 'undefined') {
  this.iNaturalist.Map = {};
};

// static functions
iNaturalist.Map.createMap = function(options) {
  if (typeof(GBrowserIsCompatible) == 'function' && GBrowserIsCompatible()){
    // Reverse compat w/ Prototype
    if (typeof Prototype != 'undefined') {
      options = $H({
        div: 'map',
        lat: 37.9,
        lng: -122.4,
        zoom: 10,
        type: G_PHYSICAL_MAP,
        controls: 'big'
      }).merge(options).toObject();
    } else {
      options = $.extend(
        {},
        {
          div: 'map',
          lat: 0,
          lng: 0,
          zoom: 1,
          type: G_PHYSICAL_MAP,
          controls: 'big'
        },
        options
      );
    }
    
    var map;
    
    if (typeof options.div == 'string') {
      map = new GMap2(document.getElementById(options.div));
    }
    else {
      map = new GMap2(options.div);
    }

    map.setCenter(new GLatLng(options.lat,
                              options.lng),
                              options.zoom);
                              
    map.enableScrollWheelZoom();
    
    if (options.controls == 'big') {
      map.addControl(new GLargeMapControl());
      map.addControl(new GMenuMapTypeControl());
    }
    else if (options.controls == 'small') {
      map.addControl(new GSmallMapControl());
      map.addControl(new GMenuMapTypeControl());
    }
    
    map.addMapType(G_PHYSICAL_MAP);
    map.setMapType(options['type']);
    
    return map;
  }
  return false;
};

// The following code should be abstracted out a bit more
iNaturalist.Map.createPlaceIcon = function(options) {
  if (typeof(options) == 'undefined') { var options = {} };
  var iconPath = "/images/mapMarkers/mm_34_stemless_";
  if (typeof(options.color) == 'undefined') {
    iconPath += "DeepPink";
  }
  else {
    iconPath += options.color;
  }
  if (typeof(options.character) != 'undefined') {
    iconPath += ('_' + options.character);
  }
  iconPath += '.png';
  var place = new GIcon();
  place.image = iconPath;
  place.iconSize = new GSize(20,20);
  place.iconAnchor = new GPoint(10,10);
  place.infoWindowAnchor = new GPoint(10,0);
  return place;
};

iNaturalist.Map.createObservationIcon = function(options) {
  if (typeof(options) == 'undefined') { var options = {} };
  
  // Choose the right settings for the observation's iconic taxon
  if (options.observation) {
    if (options.observation.iconic_taxon) {
      return iNaturalist.Map.ICONIC_TAXON_ICONS[options.observation.iconic_taxon.name];
    } else {
      return iNaturalist.Map.ICONS['unknown34'];
    };
  };
  
  var iconPath = "/images/mapMarkers/mm_34_";
  if (typeof(options.color) == 'undefined') {
    iconPath += "HotPink";
  }
  else {
    iconPath += options.color;
  }
  if (typeof(options.character) != 'undefined') {
    iconPath += ('_' + options.character);
  }
  iconPath += '.png';
  var observation = new GIcon(G_DEFAULT_ICON);
  observation.image = iconPath;
  return observation;
};

// Static constants
iNaturalist.Map.ICONS = {
  DodgerBlue34: new GIcon(G_DEFAULT_ICON, "/images/mapMarkers/mm_34_DodgerBlue.png"),
  DeepPink34: new GIcon(G_DEFAULT_ICON, "/images/mapMarkers/mm_34_DeepPink.png"),
  iNatGreen34: new GIcon(G_DEFAULT_ICON, "/images/mapMarkers/mm_34_iNatGreen.png"),
  OrangeRed34: new GIcon(G_DEFAULT_ICON, "/images/mapMarkers/mm_34_OrangeRed.png"),
  DarkMagenta34: new GIcon(G_DEFAULT_ICON, "/images/mapMarkers/mm_34_DarkMagenta.png"),
  unknown34: new GIcon(G_DEFAULT_ICON, "/images/mapMarkers/mm_34_unknown.png")
};

iNaturalist.Map.ICONIC_TAXON_ICONS = {
  Protozoa: iNaturalist.Map.ICONS.DarkMagenta34,
  Animalia: iNaturalist.Map.ICONS.DodgerBlue34,
  Plantae: iNaturalist.Map.ICONS.iNatGreen34,
  Fungi: iNaturalist.Map.ICONS.DeepPink34,
  Amphibia: iNaturalist.Map.ICONS.DodgerBlue34,
  Reptilia: iNaturalist.Map.ICONS.DodgerBlue34,
  Aves: iNaturalist.Map.ICONS.DodgerBlue34,
  Mammalia: iNaturalist.Map.ICONS.DodgerBlue34,
  Actinopterygii: iNaturalist.Map.ICONS.DodgerBlue34,
  Mollusca: iNaturalist.Map.ICONS.OrangeRed34,
  Insecta: iNaturalist.Map.ICONS.OrangeRed34,
  Arachnida: iNaturalist.Map.ICONS.OrangeRed34
};

})(); // EOF, do not erase this line!
