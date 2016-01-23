var iNatAPI = angular.module( "iNatAPI", [ ]);

iNatAPI.factory( "shared", [ "$http", "$rootScope", "$filter",
function( $http, $rootScope, $filter ) {
  var basicGet = function( url, options ) {
    options = options || { };
    if( options.cache !== true) { options.cache = false; }
    // 20 second timeout
    return $http.get( url, { cache: options.cache, timeout: 20000 } ).then(
      function( response ) {
        return response;
      }, function( errorResponse ) {
        // Handle error case
      }
    );
  };

  var numberWithCommas = function( num ) {
    if( !_.isNumber( num ) ) { return num; }
    return num.toString( ).replace( /\B(?=(\d{3})+(?!\d))/g, "," );
  };

  var t = function( k, options ) {
    options = options || { };
    return I18n.t( k, options );
  };

  var taxonStatusTitle = function( taxon ) {
    if( !taxon.conservation_status ) { return; }
    var title = $filter( "capitalize" )( taxon.conservationStatus( ), "title" );
    if( taxon.conservation_status && taxon.conservation_status.place ) {
      title = t( "status_in_place", {
        status: title, place: taxon.conservation_status.place.display_name });
    } else {
      title = t( "status_globally", { status: title });
    }
    return title;
  };

  var taxonMeansTitle = function( taxon ) {
    if( !taxon.establishment_means ) { return; }
    var title = $filter( "capitalize" )(
      t( taxon.establishment_means.establishment_means ), "title" );
    if( taxon.establishment_means && taxon.establishment_means.place ) {
      title = t( "status_in_place", {
        status: $filter( "capitalize" )(
          t( taxon.establishment_means.establishment_means, { locale: "en" }), "title" ),
        place: taxon.establishment_means.place.display_name });
    }
    return title;
  };

  var backgroundIf = function( url ) {
    if( url ) {
      return { "background-image": "url('" + url + "')" };
    }
  };

  var offsetCenter = function( options, callback ) {
    if( !options.map ) { return callback( ); }
    var overlay = new google.maps.OverlayView( );
    overlay.draw = function( ) { };
    overlay.setMap( options.map );
    var proj = overlay.getProjection( );
    var currentCenter = options.map.getCenter( );
    if( !proj ) {
      options.attempts = options.attempts || 0;
      options.attempts += 1;
      if( options.attempts >= 10 ) { return callback( currentCenter ); }
      setTimeout( function( ) {
        offsetCenter( options, callback );
      }, 5);
      return;
    }
    var cPoint = proj.fromLatLngToDivPixel( currentCenter );
    cPoint.x = cPoint.x + options.left; // left of center
    cPoint.y = cPoint.y + options.up; // north of center
    var newCenter = proj.fromDivPixelToLatLng( cPoint );
    overlay.setMap( null );
    overlay = null;
    callback( newCenter );
  };

  var processPoints = function( geometry, callback, thisArg ) {
    if( geometry instanceof google.maps.LatLng ) {
      callback.call( thisArg, geometry );
    } else if( geometry instanceof google.maps.Data.Point ) {
      callback.call( thisArg, geometry.get( ) );
    } else {
      geometry.getArray( ).forEach( function( g ) {
        processPoints( g, callback, thisArg );
      });
    }
  };

  var stringStartsWith = function( str, pattern, position ) {
    position = _.isNumber( position ) ? position : 0;
    // We use `lastIndexOf` instead of `indexOf` to avoid tying execution
    // time to string length when string doesn't start with pattern.
    return str.toLowerCase( ).lastIndexOf( pattern.toLowerCase( ), position ) === position;
  };

  var localeParams = function( ) {
    var localeParams = { locale: I18n.locale };
    if( PREFERRED_PLACE ) {
      localeParams.preferred_place_id = PREFERRED_PLACE.id;
    }
    return localeParams;
  };

  var pp = function( obj ) {
    console.log( JSON.stringify( obj, null, "  " ) );
  };

  return {
    basicGet: basicGet,
    numberWithCommas: numberWithCommas,
    t: t,
    taxonStatusTitle: taxonStatusTitle,
    taxonMeansTitle: taxonMeansTitle,
    backgroundIf: backgroundIf,
    offsetCenter: offsetCenter,
    processPoints: processPoints,
    stringStartsWith: stringStartsWith,
    localeParams: localeParams,
    pp: pp
  }
}]);

// prints a date like "Today 12:34 PM" with some stylable wrapper elements
iNatAPI.directive('inatCalendarDate', ["shared", function(shared) {
  return {
    scope: {
      date: '=',
    },
    link: function(scope, elt, attr) {
      scope.dateString = function() {
        var date = moment(scope.date),
            now = moment(new Date()),
            dateString;
        if (date.isSame(now, 'day')) {
          dateString = I18n.t('today');
        } else if (date.isSame(now.subtract(1, 'day'), 'day')) {
          dateString = I18n.t('yesterday');
        } else {
          dateString = date.format('ll');
        }
        return dateString;
      }
      scope.timeString = function() {
        return moment(scope.date).format('LT');
      }
    },
    template: '<span class="date">{{ dateString() }}</span><span class="time">{{ timeString() }}</span>'
  }
}]);

// print a taxon with correctly formatted common and scientific names
iNatAPI.directive('inatTaxon', ["shared", function(shared) {
  return {
    scope: {
      taxon: '=',
      url: '@'
    },
    link: function(scope, elt, attr) {
      scope.iconicTaxonNameForID = function(iconicTaxonID) {
        var t = window.ICONIC_TAXA[iconicTaxonID]
        if (t) {
          return t.name;
        } else {
          return 'Unknown'
        }
      };
      scope.shared = shared;
    },
    templateUrl: 'ang/templates/shared/taxon.html'
  }
}]);

iNatAPI.directive( "observationSnippet", [ "shared", function(shared) {
  return {
    scope: {
      o: '='
    },
    link: function( scope ) {
      scope.shared = shared;
    },
    templateUrl: "ang/templates/shared/observation.html"
  }
}]);
