var iNatAPI = angular.module( "iNatAPI", [ ]);

iNatAPI.factory( "shared", [ "$http", "$rootScope",
function( $http, $rootScope ) {
  var basicGet = function( url ) {
    return $http.get( url, { cache: true } ).then(
      function( response ) {
        return response;
      }, function( errorResponse ) {
        // Handle error case
      }
    );
  };

  var processParams = function( p, possibleFields ) {
    var params = _.extend( { }, p );
    // deal with iconic taxa
    if (params._iconic_taxa) {
      var iconic_taxa = [];
      angular.forEach(params._iconic_taxa, function(selected, name) {
        if (selected) {
          iconic_taxa.push(name)
        }
      });
      if( iconic_taxa.length > 0 ) {
        params.iconic_taxa = iconic_taxa;
      }
      delete params._iconic_taxa;
    }
    // date types
    // this looks and feels horrible, but I'm not sure what the angular way of doing it would be
    if( params.dateType ) {
      var keysToDelete = [ ];
      switch( params.dateType ) {
        case 'exact':
          keysToDelete = keysToDelete.concat([ "d1", "d2", "month" ]);
          break;
        case 'range':
          keysToDelete = keysToDelete.concat([ "on", "month" ]);
          break;
        case 'month':
          keysToDelete = keysToDelete.concat([ "on", "d1", "d2" ]);
          break;
        default:
          keysToDelete = keysToDelete.concat([ "on", "d1", "d2", "month" ]);
      }
      delete params.dateType;
      _.each( keysToDelete, function( k ) {
        delete params[ k ];
      });
    }
    if( possibleFields ) {
      var unknownFields = _.difference( _.keys( params ), possibleFields );
      _.each( unknownFields, function( f ) {
        delete params[ f ]
      });
    }
    _.each( _.keys( params ), function( k ) {
      if( params[ k ] === null || params[ k ] === undefined ) {
        delete params[ k ];
      }
    });
    return params;
  };

  var numberWithCommas = function( num ) {
    if( !_.isNumber( num ) ) { return num; }
    return num.toString( ).replace( /\B(?=(\d{3})+(?!\d))/g, "," );
  };

  var t = function( k, options ) {
    options = options || { };
    return I18n.t( k, options );
  };

  var offsetCenter = function( map, center, offsetx, offsety ) {
    var overlay = new google.maps.OverlayView( );
    overlay.draw = function( ) { };
    overlay.setMap( map );
    var proj = overlay.getProjection( );
    if( !proj ) { return center; }
    var cPoint = proj.fromLatLngToDivPixel( center );
    cPoint.x = cPoint.x + offsetx; // left of center
    cPoint.y = cPoint.y + offsety; // north of center
    var newCenter = proj.fromDivPixelToLatLng( cPoint );
    overlay.setMap( null );
    overlay = null;
    return newCenter;
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

  var pp = function( obj ) {
    console.log( JSON.stringify( obj, null, "  " ) );
  };

  return {
    basicGet: basicGet,
    numberWithCommas: numberWithCommas,
    processParams: processParams,
    t: t,
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

      scope.commonName = function() {
        if (!scope.taxon) { return null; }
        if (!scope.taxon.names || scope.taxon.names.length == 0) { return null; }
        var name;
        for (var i = 0; i < scope.taxon.names.length; i++) {
          if (scope.taxon.names[i].locale != 'sci') {
            name = scope.taxon.names[i].name;
            break;
          }
        }
        return name;
      }

      scope.scientificName = function() {
        if (!scope.taxon) { return null; }
        return scope.taxon.name;
      }
    },
    templateUrl: 'ang/templates/shared/taxon.html'
  }
}]);
