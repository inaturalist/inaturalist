/**
 * Select all iconic taxa and change their label classes.
 */
function selectAllIconicTaxa() {
  $$('.iconic_taxon_filter').each(function(elt) {
    elt.down('input[type=checkbox]').checked = true;
    elt.down('label').addClassName('selected');
  });
}

/**
 * Deselect all iconic taxa and change their label classes.
 */
function deSelectAllIconicTaxa() {
  $$('.iconic_taxon_filter').each(function(elt) {
    elt.down('input[type=checkbox]').checked = false;
    elt.down('label').removeClassName('selected');
  });
}

/**
 * Move map and timeline to most recent items.
 */
TimeMap.prototype.jumpToRecent = function() {
  // get most recent event and center the first timeline band there
  var band = this.timeline.getBand(0);
  var eventSource = band.getEventSource();
  band.setCenterVisibleDate(eventSource.getLatestDate())
  
  // set the map extents to the padded bounding box of those items
  var iter = eventSource.getEventIterator(
    band.getMinVisibleDate(), band.getMaxVisibleDate());
  var bounds = new GLatLngBounds();
  while (iter.hasNext()) {
    var next = iter.next();
    if (typeof(next.item.placemark) != 'undefined') {
      bounds.extend(next.item.placemark.getLatLng());
    }
  }
  this.map.setZoom(this.map.getBoundsZoomLevel(bounds));
  this.map.setCenter(bounds.getCenter());
}

/**
 * Convert iNat observations to TimeMap-formatted JSON.
 */
function observation2tm(obs) {
  var tmobs = {
    'options': {'infoHtml' : $('mini-observation-'+obs.id)}
  };
  tmobs.title = 'Something';
  if (obs.species_guess != undefined && obs.species_guess != '' &&
      obs.species_guess != null) {
    tmobs.title = obs.species_guess;
  }
  
  tmobs.start = '';
  if (obs.observed_on != undefined && obs.observed_on) {
    tmobs.start = obs.observed_on.gsub('/', '-');
  }
  
  tmobs.point = {};
  if (obs.latitude != undefined && obs.latitude &&
      obs.longitude != undefined && obs.longitude) {
    tmobs.point = { lat: parseFloat(obs.latitude),
                    lon: parseFloat(obs.longitude) };
  }

  return tmobs;
}

// Setup our themes
TimeMapDataset.redTheme = function() {
    var markerIcon = iNaturalist.Map.createObservationIcon({});

    return new TimeMapDatasetTheme({
        icon: markerIcon, 
        color: "#8E67FD",
        eventIcon: "/images/mapMarkers/mm_20_stemless_DeepPink.png"
    });
};

TimeMapDataset.greenTheme = function() {
    var markerIcon = iNaturalist.Map.createObservationIcon({color: 'iNatGreen'});

    return new TimeMapDatasetTheme({
        icon: markerIcon, 
        color: "#74AC00",
        eventIcon: "/images/mapMarkers/mm_20_stemless_iNatGreen.png"
    });
};

TimeMapDataset.orangeTheme = function() {
    var markerIcon = iNaturalist.Map.createObservationIcon({color: 'OrangeRed'});

    return new TimeMapDatasetTheme({
        icon: markerIcon, 
        color: "#ff4500",
        eventIcon: "/images/mapMarkers/mm_20_stemless_OrangeRed.png"
    });
};

TimeMapDataset.unknownTheme = function() {
    var markerIcon = iNaturalist.Map.createObservationIcon({color: 'unknown'});

    return new TimeMapDatasetTheme({
        icon: markerIcon, 
        color: "#333333",
        eventIcon: "/images/mapMarkers/mm_20_stemless_unknown.png"
    });
};

TimeMapDataset.blueTheme = function() {
    var markerIcon = iNaturalist.Map.createObservationIcon({color: 'DodgerBlue'});

    return new TimeMapDatasetTheme({
        icon: markerIcon, 
        color: "#1e90ff",
        eventIcon: "/images/mapMarkers/mm_20_stemless_DodgerBlue.png"
    });
};

function setupTimeMap() {
  var tm = new TimeMap($('timeline'), $('map'), {});
  window.tm = tm;
  var chordataSample = tm.createDataset("chordata", {
    title:  "Animals (Vertebrates & Misc.)",
    theme:  TimeMapDataset.blueTheme()
  });
  var plantaeSample = tm.createDataset("plantae", {
    title:  "Plants",
    theme:  TimeMapDataset.greenTheme()
  });
  var fungiSample = tm.createDataset("fungi", {
    title:  "Fungi",
    theme:  TimeMapDataset.redTheme()
  });
  var invertebratesSample = tm.createDataset("invertebrates", {
    title:  "Invertebrates",
    theme:  TimeMapDataset.orangeTheme()
  });
  var unknownSample = tm.createDataset("unknown", {
    title:  "Unknown",
    theme:  TimeMapDataset.unknownTheme()
  });
  
  fungiSample.eventSource = chordataSample.eventSource;
  plantaeSample.eventSource = chordataSample.eventSource;
  invertebratesSample.eventSource = chordataSample.eventSource;
  unknownSample.eventSource = chordataSample.eventSource;
  
  var bands = [
    Timeline.createBandInfo({
        eventSource:    fungiSample.eventSource,
        width:          "80%",
        intervalPixels: 100,
        intervalUnit:   Timeline.DateTime.DAY
    }),
    Timeline.createBandInfo({
        eventSource:    null,
        width:          "20%",
        intervalUnit:   Timeline.DateTime.MONTH,
        intervalPixels: 100,
        trackHeight:    0.75,
        trackGap:       0.2
    })
  ];
  
  tm.initTimeline(bands);
  
  observations = observations.compact();
  observations.each(function(obs) {
    if (typeof(obs.latitude) != 'undefined' && obs.latitude != null &&
        typeof(obs.longitude) != 'undefined' && obs.longitude != null &&
        typeof(obs.observed_on) != 'undefined' && obs.observed_on != null) {
      if (typeof(obs.iconic_taxon) == 'undefined' || !obs.iconic_taxon) {
        unknownSample.loadItem(obs, observation2tm);
      } else {
        switch(obs.iconic_taxon.name) {
          case 'Animalia':
            chordataSample.loadItem(obs, observation2tm);
            break;
          case 'Mollusca':
            invertebratesSample.loadItem(obs, observation2tm);
            break;
          case 'Arachnida':
            invertebratesSample.loadItem(obs, observation2tm);
            break;
          case 'Insecta':
            invertebratesSample.loadItem(obs, observation2tm);
            break;
          case 'Amphibia':
            chordataSample.loadItem(obs, observation2tm);
            break;
          case 'Reptilia':
            chordataSample.loadItem(obs, observation2tm);
            break;
          case 'Aves':
            chordataSample.loadItem(obs, observation2tm);
            break;
          case 'Mammalia':
            chordataSample.loadItem(obs, observation2tm);
            break;
          case 'Plantae':
            plantaeSample.loadItem(obs, observation2tm);
            break;
          case 'Fungi':
            fungiSample.loadItem(obs, observation2tm);
            break;
        } 
      }
    };
  });
  if (typeof(tdate) != 'undefined' && tdate instanceof Date) {
    tm.timeline.getBand(0).setCenterVisibleDate(tdate);
  } 
  else {
    tm.timeline.getBand(0).setCenterVisibleDate(
      tm.timeline.getBand(0).getEventSource().getLatestDate());
  }
  tm.timeline.layout();
}


Event.observe(window, 'load', function() {
  // Add click behavior for iconic taxon checkboxes
  $$('.iconic_taxon_filter').each(function(filter) {
    filter.down('input').observe('change', function(e) {
      var filter = Event.element(e).up('.iconic_taxon_filter');
      filter.down('label').toggleClassName('selected');
      new Effect.Highlight('submit_filters_button', {
        startcolor: '#1E90FF', 
        endcolor: '#3366CC',
        restorecolor: '#3366CC'}); // just until we get the AJAX form submission working
    });
  });
  $$('#filters input').each(function(input) {
    input.observe('change', function(e) {
      $('time_to').show();
    });
  });
  
  setupTimeMap();
  
  // Map Controls
  window.tm.map.addControl(new GOverviewMapControl());
  window.tm.map.enableGoogleBar();
  
  
  // Keep the filter form updated with the map position
  GEvent.addListener(tm.map, 'moveend', function() {
    var center = this.getCenter();
    $('lat').value = center.lat();
    $('lon').value = center.lng();
    $('zoom').value = this.getZoom();
  });
  
  // Keep the filter form updated with the timeline center
  tm.timeline.getBand(0).addOnScrollListener(function(band) {
    var year = band.getCenterVisibleDate().getFullYear();
    var month = (band.getCenterVisibleDate().getMonth()+1).toPaddedString(2);
    var date = band.getCenterVisibleDate().getDate().toPaddedString(2);
    $('tdate').value = year + '/' + month + '/' + date;
  });
  
  // Set the map exent
  if (typeof(mlat) != 'undefined' && 
      typeof(mlon) != 'undefined' && 
      typeof(mzoom) != 'undefined') {
    // console.log("Setting requested extent...");
    tm.map.setZoom(mzoom);
    tm.map.setCenter(new GLatLng(mlat, mlon));
  } else if (observations.length != 0) {
    // zoom the map to the extent of the observations
    // console.log("Setting extent to bbox of observations...");
     var bounds = new GLatLngBounds();
     observations.each(function(o) {
       if (typeof(o.latitude) != 'undefined' && o.latitude &&
           typeof(o.longitude) != 'undefined' && o.longitude) {
         bounds.extend(new GLatLng(o.latitude, o.longitude));
       }
     });
     tm.map.setZoom(tm.map.getBoundsZoomLevel(bounds));
     tm.map.setCenter(bounds.getCenter());
  } else {
    // console.log("Just setting the zoom level");
    tm.map.setZoom(3);
  }
});
