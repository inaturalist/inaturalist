/* global _ */
/* global angular */
/* global google */
/* global moment */
/* global rison */
/* global iNatModels */
/* global I18n */
/* global CURRENT_USER */

var iNatAPI = angular.module( "iNatAPI", [] );
iNatAPI.constant( "testingApiV2", ( CURRENT_USER.testGroups && CURRENT_USER.testGroups.includes( "apiv2" ) )
  || window.location.search.match( /test=apiv2/ ) );

iNatAPI.factory( "shared", ["$http", "$rootScope", "$filter", "testingApiV2",
  function ( $http, $rootScope, $filter, testingApiV2 ) {
    var basicGet = function ( url, inputParams = { } ) {
      var params = _.extend( { }, inputParams );
      var config = {
        timeout: 60000 // 60 second timeout
      };
      var apiURL = $( "meta[name='config:inaturalist_api_url']" ).attr( "content" );
      if ( testingApiV2 ) {
        apiURL = apiURL.replace( "/v1", "/v2" );
        if ( params.fields ) {
          params.fields = rison.encode( params.fields );
        }
      } else {
        delete params.fields;
      }
      var apiToken = $( "meta[name='inaturalist-api-token']" ).attr( "content" );
      if ( apiToken ) {
        config.headers = {
          Authorization: apiToken
        };
      }
      var getURL = apiURL + url;
      if ( !_.isEmpty( params ) ) {
        getURL += "?" + $.param( params );
      }

      return $http.get( getURL, config ).then( function ( response ) {
        return response;
      }, function ( errorResponse ) {
        // Handle error case
        if ( errorResponse && errorResponse.data && errorResponse.data.error ) {
          if ( errorResponse.data.error.match( /window is too large/ ) ) {
            // eslint-disable-next-line no-alert
            alert( I18n.t( "result_window_too_large_error" ).replace( /\s+/g, " " ) );
          } else {
            // eslint-disable-next-line no-alert
            alert( errorResponse.data.error );
          }
        } else if ( errorResponse && errorResponse.status && errorResponse.status > 0 ) {
          // eslint-disable-next-line no-alert
          alert( I18n.t( "doh_something_went_wrong" ) );
        } else {
          // Unfortunately Firefox will fire the error callback when a promise
          // gets cancelled, say due to a page reload, so we should not show
          // an error here or people will see it when they reload the page or
          // navigate to a different page while a request is in flight. Even
          // more unfortunately, Firefox does exactly the same thing when the
          // connection fails, e.g. the API is down.
        }
      } );
    };

    var numberWithCommas = function ( num ) {
      if ( !_.isNumber( num ) ) { return num; }
      return I18n.toNumber( num, { precision: 0 } );
    };

    var t = function ( k, opts = { } ) {
      var options = _.extend( { }, opts );
      return I18n.t( k, options );
    };

    var l = function ( format, value ) {
      return I18n.l( format, moment( value ) );
    };

    var pluralWithoutCount = function ( key, count ) {
      var s = I18n.t( key, { count: count } );
      s = s.replace( /<span.*?>.+?<\/span>/g, "" );
      s = s.replace( count, "" );
      return s;
    };

    var taxonStatusTitle = function ( taxon ) {
      if ( !taxon.conservation_status ) { return null; }
      var title = $filter( "capitalize" )( taxon.conservationStatus( ), "title" );
      if ( taxon.conservation_status && taxon.conservation_status.place ) {
        title = t( "status_in_place", {
          status: title,
          place: taxon.conservation_status.place.display_name
        } );
      } else {
        title = t( "status_globally", { status: title } );
      }
      return title;
    };

    var taxonMeansTitle = function ( taxon ) {
      if ( !taxon.establishment_means ) { return null; }
      var title = $filter( "capitalize" )( t(
        taxon.establishment_means.establishment_means
      ), "title" );
      if ( taxon.establishment_means && taxon.establishment_means.place ) {
        title = t( "status_in_place", {
          status: $filter( "capitalize" )( t(
            taxon.establishment_means.establishment_means,
            { locale: "en" }
          ), "title" ),
          place: taxon.establishment_means.place.display_name
        } );
      }
      return title;
    };

    var backgroundIf = function ( url ) {
      if ( url ) {
        return { "background-image": "url('" + url + "')" };
      }
      return null;
    };

    var offsetCenter = function ( opts, callback ) {
      var options = _.extend( { }, opts || { } );
      if ( !options.map ) { return callback( ); }
      if ( typeof ( google ) === "undefined" ) { return callback( ); }
      var overlay = new google.maps.OverlayView( );
      overlay.draw = function ( ) { };
      overlay.onAdd = function ( ) { };
      overlay.onRemove = function ( ) { };
      overlay.setMap( options.map );
      var proj = overlay.getProjection( );
      var currentCenter = options.map.getCenter( );
      if ( !proj ) {
        options.attempts = options.attempts || 0;
        options.attempts += 1;
        if ( options.attempts >= 10 ) { return callback( currentCenter ); }
        setTimeout( function ( ) {
          offsetCenter( options, callback );
        }, 5 );
        return null;
      }
      var cPoint = proj.fromLatLngToDivPixel( currentCenter );
      cPoint.x += options.left; // left of center
      cPoint.y += options.up; // north of center
      var newCenter = proj.fromDivPixelToLatLng( cPoint );
      overlay.setMap( null );
      overlay = null;
      callback( newCenter );
      return null;
    };

    var processPoints = function ( geometry, callback, thisArg ) {
      if ( !geometry ) { return null; }
      if ( typeof ( google ) === "undefined" ) { return callback( ); }
      if ( geometry instanceof google.maps.LatLng ) {
        callback.call( thisArg, geometry );
      } else if ( geometry instanceof google.maps.Data.Point ) {
        callback.call( thisArg, geometry.get( ) );
      } else {
        geometry.getArray( ).forEach( function ( g ) {
          processPoints( g, callback, thisArg );
        } );
      }
      return null;
    };

    var stringStartsWith = function ( str, pattern, pos ) {
      var position = _.isNumber( pos ) ? pos : 0;
      // We use `lastIndexOf` instead of `indexOf` to avoid tying execution
      // time to string length when string doesn't start with pattern.
      return str.toLowerCase( ).lastIndexOf( pattern.toLowerCase( ), position ) === position;
    };

    var pp = function ( obj ) {
      // eslint-disable-next-line no-console
      console.log( JSON.stringify( obj, null, "  " ) );
    };

    return {
      basicGet: basicGet,
      numberWithCommas: numberWithCommas,
      t: t,
      l: l,
      pluralWithoutCount: pluralWithoutCount,
      taxonStatusTitle: taxonStatusTitle,
      taxonMeansTitle: taxonMeansTitle,
      backgroundIf: backgroundIf,
      offsetCenter: offsetCenter,
      processPoints: processPoints,
      stringStartsWith: stringStartsWith,
      pp: pp
    };
  }] );

// prints a date like "Today 12:34 PM" with some stylable wrapper elements
iNatAPI.directive( "inatCalendarDate", ["shared", function ( shared ) {
  return {
    scope: {
      time: "=",
      date: "=",
      timezone: "=",
      obscured: "=",
      short: "="
    },
    // eslint-disable-next-line no-unused-vars
    link: function ( scope, elt, attr ) {
      // eslint-disable-next-line no-param-reassign
      scope.dateString = function ( ) {
        if ( !scope.date ) {
          return shared.t( "missing_date" );
        }
        if ( scope.obscured ) {
          return moment( scope.date ).format(
            scope.short
              ? I18n.t( "momentjs.month_year_short" )
              : I18n.t( "momentjs.month_year" )
          );
        }
        var date = moment( scope.date );
        var now = moment( new Date( ) );
        var dateString;
        if ( date.isSame( now, "day" ) ) {
          dateString = I18n.t( "today" );
        } else if ( date.isSame( now.subtract( 1, "day" ), "day" ) ) {
          dateString = I18n.t( "yesterday" );
        } else {
          dateString = date.format( "ll" );
        }
        return dateString;
      };
      // eslint-disable-next-line no-param-reassign
      scope.timeString = function ( ) {
        if ( !scope.time ) return "";
        if ( scope.obscured ) return "";
        // eslint-disable-next-line no-param-reassign
        var timezone = scope.timezone || "UTC";
        return moment.tz( scope.time.replace( /[+-]\d\d:\d\d/, "" ), timezone ).format( "LT z" );
      };
    },
    template: "<span class=\"date\">{{ dateString() }}</span><span class=\"time\">{{ timeString() }}</span>"
  };
}] );

// print a taxon with correctly formatted common and scientific names
iNatAPI.directive( "inatTaxon", ["shared", function ( shared ) {
  return {
    scope: {
      taxon: "=",
      url: "@"
    },
    // eslint-disable-next-line no-unused-vars
    link: function ( scope, elt, attr ) {
      // eslint-disable-next-line no-param-reassign
      scope.iconicTaxonNameForID = function ( iconicTaxonID ) {
        var t = window.ICONIC_TAXA[iconicTaxonID];
        if ( t ) {
          return t.name;
        }
        return "Unknown";
      };
      // eslint-disable-next-line no-param-reassign
      scope.shared = shared;
      // eslint-disable-next-line no-param-reassign
      scope.user = CURRENT_USER;
      // eslint-disable-next-line no-param-reassign
      scope.displayNames = function ( ) {
        var names = [];
        if ( !scope.taxon ) { return null; }
        if ( scope.user && scope.user.prefers_scientific_name_first ) {
          names.push( scope.taxon.name );
        } else if ( !_.isEmpty( scope.taxon.preferred_common_names ) ) {
          names = _.map( scope.taxon.preferred_common_names, function ( taxonName ) {
            return iNatModels.Taxon.titleCaseName( taxonName.name );
          } );
        } else if ( scope.taxon.preferred_common_name ) {
          names.push( iNatModels.Taxon.titleCaseName( scope.taxon.preferred_common_name ) );
        } else {
          names.push( scope.taxon.name );
        }
        return names;
      };
      // eslint-disable-next-line no-param-reassign
      scope.secondaryNames = function ( ) {
        var names = [];
        if ( !scope.taxon ) { return null; }
        if ( scope.user && scope.user.prefers_scientific_name_first ) {
          if ( !_.isEmpty( scope.taxon.preferred_common_names ) ) {
            names = _.map( scope.taxon.preferred_common_names, function ( taxonName ) {
              return iNatModels.Taxon.titleCaseName( taxonName.name );
            } );
          } else if ( scope.taxon.preferred_common_name ) {
            names.push( iNatModels.Taxon.titleCaseName( scope.taxon.preferred_common_name ) );
          }
        } else if ( scope.taxon.preferred_common_name ) {
          names.push( scope.taxon.name );
        }
        return names;
      };
      // eslint-disable-next-line no-param-reassign
      scope.showRank = function ( ) {
        return scope.taxon && scope.taxon.rank_level > 10;
      };
      // eslint-disable-next-line no-param-reassign
      scope.rank = function ( ) {
        if ( !scope.taxon || !scope.taxon.rank ) { return null; }
        return I18n.t( "ranks." + scope.taxon.rank.toLowerCase( ), {
          defaultValue: scope.taxon.rank
        } );
      };
    },
    templateUrl: "ang/templates/shared/taxon.html"
  };
}] );

iNatAPI.directive( "observationSnippet", ["shared", function ( shared ) {
  return {
    scope: { o: "=" },
    link: function ( scope ) {
      // eslint-disable-next-line no-param-reassign
      scope.shared = shared;
    },
    templateUrl: "ang/templates/shared/observation.html"
  };
}] );

iNatAPI.directive( "userIcon", ["shared", function ( shared ) {
  return {
    scope: { u: "=" },
    link: function ( scope ) {
      // eslint-disable-next-line no-param-reassign
      scope.shared = shared;
    },
    templateUrl: "ang/templates/shared/user_icon.html"
  };
}] );

iNatAPI.directive( "userLogin", [function ( ) {
  return {
    scope: { u: "=" },
    templateUrl: "ang/templates/shared/user_login.html"
  };
}] );
