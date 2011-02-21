$(document).ready(function() {        
  // View behavior
  $('#tablelink').click(function() {
    $('#controls .modal_link').removeClass('selected')
    $(this).addClass('selected')
    showTableView()
    if (!(jQuery.browser.msie && parseInt(jQuery.browser.version.substr(0,1)) < 7)) {
      return false
    }
  })
  $('#maplink').click(function() {
    $('#controls .modal_link').removeClass('selected')
    $(this).addClass('selected')
    showMapView()
    if (!(jQuery.browser.msie && parseInt(jQuery.browser.version.substr(0,1)) < 7)) {
      return false
    }
  })
  
  // Filter behavior
  $('#filterslink').click(function() {
    toggleFilters(this, {skipClass: true})
    $(this).parent().toggleClass("open")
    if ($(this).parent().hasClass('open')) {
      alterLinkParams({filters_open: 'true'})
    } else {
      alterLinkParams({filters_open: 'false'})
    }
    return false
  })
})

function showMapView() {
  $('.observations.map').show();
  $('.observations .headerrow').hide();
  $('#mapobservations').css({width: '300px', height: '500px'});
  $('#mapobservations').removeClass('table');
  $('#mapobservations').addClass('mini');
  $('#mapdivider').show();
  $('#mapcontrols').show();
  if ($('#mapdivider').hasClass('closed')) $('#mapobservations').hide();
  if (window.map) {
    window.map.checkResize();
    if (window.map._oldCenter) {
      window.map.setCenter(window.map._oldCenter)
      window.map._oldCenter = null
    } else {
      window.map.zoomToObservations()
    }
  }
  alterLinkParams({view: 'map'});
  $('#view_input').val('map');
}

function showTableView() {
  if (window.map) {
    window.map._oldCenter = window.map.getCenter()
  }
  $('.observations.map').hide();
  $('#mapdivider').hide();
  $('#mapcontrols').hide();
  $('.observations .headerrow').show();
  $('#mapobservations').show();
  $('#mapobservations').css({width: '950px', height: 'auto'});
  $('#mapobservations').removeClass('mini');
  $('#mapobservations').addClass('table');
  alterLinkParams({view: 'table'});
  $('#view_input').val('table');
}

// Alters the href of all links using the passed in params. So if you have
// a link to '/observations?view=map' and you 
// alterLinkParams({map: 'table'}), the link will become
// '/observations?view=table'
// Yes, this is a lame hack.
function alterLinkParams(params) {
  $('#wrapper a[href^=/observations?]').each(function() {
    var href = $(this).attr('href');
    var path = jQuery.url.setUrl(href).attr('path');
    var queryString = jQuery.url.setUrl(href).attr('query');
    queryObj = $.extend({}, queryString2Obj(queryString), params);
    $(this).attr('href', path + '?' + obj2QueryString(queryObj));
  });
}

// Convert a URL query string to an object literal
function queryString2Obj(str) {
  var pieces = str.split('&');
  var obj = {};
  jQuery.each(pieces, function() {
    var bits = this.split('=');
    obj[bits[0]] = bits[1];
  });
  return obj;
}

function obj2QueryString(obj) {
  var pieces = [];
  jQuery.each(obj, function(k,v) {
    pieces.push(k+'='+v); 
  });
  return pieces.join('&');
}

function redoSearchInMapArea() {
  $('#redo_search_in_map_area_button').hide();
  $('#redo_search_in_map_area_loading').show();
  var bounds = map.getBounds();
  $('#filters input[name=swlat]').val(bounds.getSouthWest().lat());
  $('#filters input[name=swlng]').val(bounds.getSouthWest().lng());
  $('#filters input[name=nelat]').val(bounds.getNorthEast().lat());
  $('#filters input[name=nelng]').val(bounds.getNorthEast().lng());
  $('#submit_filters_button').click();
}
