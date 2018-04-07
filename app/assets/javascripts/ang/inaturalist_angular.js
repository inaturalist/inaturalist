var iNatAPI = angular.module( "iNatAPI", [ ]);

iNatAPI.factory( "shared", [ "$http", "$rootScope", "$filter",
function( $http, $rootScope, $filter ) {
  var basicGet = function( url, options ) {
    options = options || { };
    if( options.cache !== true ) { options.cache = false; }
    var config = {
      cache: options.cache,
      timeout: 20000 // 20 second timeout
    };
    var apiURL = $( "meta[name='config:inaturalist_api_url']" ).attr( "content" );
    if ( apiURL && url.indexOf( apiURL ) >= 0 ) {
      var apiToken = $( "meta[name='inaturalist-api-token']" ).attr( "content" );
      if ( apiToken ) {
        config.headers = {
          Authorization: apiToken
        }
      }
    }
    return $http.get( url, config ).then(
      function( response ) {
        return response;
      }, function( errorResponse ) {
        // Handle error case
      }
    );
  };

  var numberWithCommas = function( num ) {
    if( !_.isNumber( num ) ) { return num; }
    return I18n.toNumber( num, { precision: 0 } );
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
    if( !geometry ) { return; }
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
    pp: pp
  }
}]);

// prints a date like "Today 12:34 PM" with some stylable wrapper elements
iNatAPI.directive('inatCalendarDate', ["shared", function(shared) {
  return {
    scope: {
      time: "=",
      date: "=",
      timezone: "="
    },
    link: function(scope, elt, attr) {
      scope.dateString = function() {
        if( !scope.date ) {
          return shared.t('unknown');
        }
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
        if( !scope.time ) { return; }
        scope.timezone = scope.timezone || "UTC";
        return moment(scope.time).tz(scope.timezone).format("LT z");
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
      scope.user = CURRENT_USER;
      scope.displayName = function() {
        var name;
        if ( !scope.taxon ) { return; }
        if ( scope.user && scope.user.prefers_scientific_name_first ) {
          name = scope.taxon.name;
        } else if ( scope.taxon.preferred_common_name ) {
          name = iNatModels.Taxon.titleCaseName( scope.taxon.preferred_common_name );
        }
        return name || scope.taxon.name;
      }
      scope.secondaryName = function() {
        var name;
        if ( !scope.taxon ) { return; }
        if ( scope.user && scope.user.prefers_scientific_name_first ) {
          name = iNatModels.Taxon.titleCaseName( scope.taxon.preferred_common_name );
        } else if ( scope.taxon.preferred_common_name ) {
          name = scope.taxon.name;
        }
        return name;
      }
      scope.showRank = function() {
        return scope.taxon && scope.taxon.rank_level > 10;
      }
    },
    templateUrl: 'ang/templates/shared/taxon.html'
  }
}]);

iNatAPI.directive( "observationSnippet", [ "shared", function( shared ) {
  return {
    scope: { o: "=" },
    link: function( scope ) {
      scope.shared = shared;
    },
    templateUrl: "ang/templates/shared/observation.html"
  };
}]);

iNatAPI.directive( "userIcon", [ "shared", function( shared ) {
  return {
    scope: { u: "=" },
    link: function( scope ) {
      scope.shared = shared;
    },
    templateUrl: "ang/templates/shared/user_icon.html"
  };
}]);

iNatAPI.directive( "userLogin", [ function( ) {
  return {
    scope: { u: "=" },
    templateUrl: "ang/templates/shared/user_login.html"
  };
}]);
