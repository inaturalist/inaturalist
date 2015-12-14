var application = angular.module( "ObservationSearch", [
  "infinite-scroll",
  "ngRoute",
  "templates",
  "ehFilters", // angular-capitalize
  "iNatAPI",
  "ui.bootstrap",
  "angularMoment",
  "truncate"
]);

// http://stackoverflow.com/a/22965260
moment.locale('en', {
  relativeTime : {
    future: "in %s",
    past:   "%s",
    s:  "seconds",
    m:  "1m",
    mm: "%dm",
    h:  "1h",
    hh: "%h",
    d:  "1d",
    dd: "%dd",
    M:  "1m",
    MM: "%dm",
    y:  "1y",
    yy: "%dy"
  }
});

// defining the views
application.directive( "resultsMap", function( ) {
  return {
    templateUrl: "ang/templates/observation_search/results_map.html",
    link: function( scope, element, attr ) {
      scope.$watch( attr.ngShow, function( value ) {
        if( value === true ) {
          // wait 50ms for the map view to render so the #map element exists
          setTimeout( function( ) {
            // create the map if it doesn't exist
            if( !scope.map ) { return scope.setupMap( ); }
            // if it does, and a search has happened when on another view,
            // line up the map with the searched place
            if( scope.$parent.mapNeedsAligning ) { scope.setMapLayers( true ); }
          }, 50);
        }
      });
      // the observation div on the map is a scrollable div in a scrollable page
      // make sure that when you scroll to the botton of that div, the page
      // doesn't start scrolling down
      $( "#obs" ).isolatedScroll( );
    }
  };
});

// disable scrolling to the top when we're updating the view
application.value( "$anchorScroll", angular.noop );

application.config( [ "$locationProvider", function($locationProvider) {
  $locationProvider.html5Mode({
    enabled: true
  });
}]);

application.controller( "SearchController", [ "ObservationsFactory", "PlacesFactory",
"TaxaFactory", "shared", "$scope", "$rootScope", "$location",
function( ObservationsFactory, PlacesFactory, TaxaFactory, shared, $scope, $rootScope, $location ) {
  $scope.shared = shared;
  $scope.possibleViews = [ "observations", "species", "identifiers", "observers" ];
  $scope.possibleSubviews = { observations: [ "map", "grid", "table" ] };
  $scope.possibleFields = [ "iconic_taxa", "month", "swlat", "swlng",
    "nelat", "nelng", "place_id", "taxon_id", "page", "view", "subview" ];
  $scope.defaultView = "observations";
  $scope.defaultSubview = "map";
  $scope.defaultParams = {
    photos: true,
    order_by: "observations.id",
    order: "desc",
    dateType: "any",
    page: 1
  };
  $scope.mapCenter = { lat: 0, lng: 130 };
  $scope.mapZoom = 1;
  $scope.nearbyPlaces = [ ];
  $scope.taxonInitialized = false;
  $scope.placeInitialized = false;
  $scope.filtersInitialized = false;
  $scope.parametersInitialized = false;

  // this is the first block to run when the page loads
  $scope.preInitialize = function( ) {
    $scope.resetStats( );         // all stats read ---
    $scope.matchUrlState( );      // set the right view
    $scope.setInitialParams( );   // set params from URL, lookup place and taxon
  };

  // once the initial state is prepared from the URL and params loaded
  $scope.afterParametersInitialized = function( ) {
    if( $scope.taxonInitialized && $scope.placeInitialized &&
        $scope.filtersInitialized && !$scope.parametersInitialized ) {
      $scope.searchAndUpdateStats( );           // fetch the observations
      $rootScope.$emit( "setMapLayers", true ); // set proper map layers for the search and orient the map
      $scope.watchParams( );                    // now we watch for param changes
      $scope.parametersInitialized = true;
    }
  };
  // any time an initialization step finishes, attempt afterInitialize
  $scope.$watchGroup([ "taxonInitialized", "filtersInitialized",
                       "placeInitialized" ], function( ) {
    $scope.afterParametersInitialized( );
  });
  // when searching places from non-map tabs (map is not visible)
  // indicate the map will need to be realigned when visiable again
  $scope.$watchGroup([ "mapCenter", "mapBounds", "mapZoom" ], function( ) {
    if( !$scope.viewing( "observations", "map" ) ) {
      $scope.mapNeedsAligning = true;
    }
  });
  // runs when the filters template has been rendered
  $scope.onFiltersLoad = function( ) {
    $scope.setupFilterToggle( );
    $scope.setupDatepicker( );
    $scope.setupPlaceSearchbox( );
    $scope.setupMiltiselects( );
    $scope.determineFieldNames( );
    $scope.setupTaxonAutocomplete( );
    $scope.filtersInitialized = true;
  };
  $scope.resetStats = function( ) {
    _.each([ "totalObservations", "totalSpecies", "totalObservers", "totalIdentifiers" ], function( k ) {
      $scope[ k ] = "--";
    });
    _.each([ "taxa", "identifiers", "observers" ], function( k ) {
      $scope[ k ] = [ ];
    });
  };
  $scope.resetParams = function( ) {
    $scope.params = _.extend( { }, $scope.defaultParams );
    $scope.closeFilters();
  };
  $scope.closeFilters = function( ) {
    $( "#filter-container" ).removeClass( "open" );
  };
  $scope.watchParams = function( ) {
    // params may change but not affect the results
    // for example DateType will change with the different date options
    $scope.$watch( "params", function( ) {
      $scope.processedParams = shared.processParams( $scope.params, $scope.possibleFields );
    }, true);
    // changes in processedParams are what initiate searches
    $scope.$watch( "processedParams", function( before, after ) {
      if( _.isEqual( before, after ) ) { return; }
      $scope.searchAndUpdateStats( );
      $rootScope.$emit( "setMapLayers", $scope.alignMapOnSearch );
      // restore some one-time search settings
      $scope.alignMapOnSearch = false;
    }, true);
  };
  // watch for place selections, unselections
  $scope.$watch( "selectedPlace", function( ) {
    if( $scope.selectedPlace && $scope.selectedPlace.id ) {
      if( $scope.params.place_id != $scope.selectedPlace.id ) {
        $scope.mapCenter = null;
        $scope.mapBounds = null;
        $scope.mapZoom = null;
        $scope.alignMapOnSearch = true;
        $scope.params.place_id = $scope.selectedPlace.id;
      }
    } else {
      delete $scope.params.place_id;
    }
  });
  $scope.initializeTaxonParams = function( ) {
    if( $scope.params.taxon_id ) {
      $scope.params.taxon_id = parseInt( $scope.params.taxon_id );
    }
    if( $scope.params.taxon_id ) {
      // load taxon auto name and photo for autocomplete
      TaxaFactory.show( $scope.params.taxon_id ).then( function( response ) {
        taxa = TaxaFactory.responseToInstances( response );
        if( taxa.length > 0 ) {
          var taxon = taxa[ 0 ];
          if( taxon.square_photo_url ) {
            $( "#filters .ac-select-thumb img" ).attr( "src", taxon.square_photo_url );
          }
          $( "input[name='taxon_name']" ).attr( "value", taxon.preferredNameInLocale( "en" ) );
        }
        $scope.taxonInitialized = true;
      });
    } else { $scope.taxonInitialized = true; }
  };
  $scope.initializePlaceParams = function( ) {
    if( $scope.params.place_id ) {
      $scope.params.place_id = parseInt( $scope.params.place_id );
    }
    if( $scope.params.place_id ) {
      // load place name and polygon from ID
      PlacesFactory.show( $scope.params.place_id ).then( function( response ) {
        places = PlacesFactory.responseToInstances( response );
        if( places.length > 0 ) {
          $scope.filterByPlace( places[ 0 ] );
        }
        $scope.placeInitialized = true;
      });
    } else {
      // otherwise set the starting mapBounds
      if( $scope.params.swlat && $scope.params.swlng &&
          $scope.params.nelat && $scope.params.nelng ) {
        $scope.mapCenter = null;
        $scope.mapZoom = null;
        $scope.mapBounds = new google.maps.LatLngBounds(
            new google.maps.LatLng( $scope.params.swlat, $scope.params.swlng ),
            new google.maps.LatLng( $scope.params.nelat, $scope.params.nelng ));
      }
      $scope.placeInitialized = true;
    }
  };
  // set params from the URL and lookup any Taxon or Place selections
  $scope.setInitialParams = function( ) {
    $scope.params = _.extend( { }, $scope.defaultParams, $location.search( ) );
    $scope.initializeTaxonParams( );
    $scope.initializePlaceParams( );
  };
  $scope.updateBrowserLocation = function( ) {
    var newParams = [ ];
    _.each( $scope.params, function( value, param ) {
      // don't show default params in the URL
      if( $scope.defaultParams.hasOwnProperty( param ) && value === $scope.defaultParams[ param ] ) {
        return;
      }
      // assess view and subview params below
      if( param == "view" || param == "subview" ) { return; }
      newParams.push( [ param, value ] );
    });
    if( $scope.currentView != $scope.defaultView ) {
      newParams.push( [ "view", $scope.currentView ] );
    }
    if( $scope.currentSubview != $scope.defaultSubview ) {
      newParams.push( [ "subview", $scope.currentSubview ] );
    }
    // keep param order consistent
    newParams = _.sortBy( newParams, function( arr ) {
      return arr[ 0 ];
    });
    if( !_.isEmpty( newParams ) ) {
      var urlParams = shared.processParams( _.object( newParams ), $scope.possibleFields );
      urlParams = _.mapObject( urlParams, function( v, k ) {
        if( _.isArray( v ) ) { return v.join(","); }
        if( $scope.defaultParams[ k ] === true && v !== true ) { v = "any"; }
        return v;
      });
      // store the params in the browser history state
      $location.state( urlParams );
      $location.search( urlParams );
    } else {
      // going back to the initial state, so record that
      $location.state({ });
      $location.search({ });
    }
  };
  $scope.viewing = function( view, subview ) {
    if( subview ) {
      if( view == $scope.currentView && subview == $scope.currentSubview ) {
        return true;
      }
    } else if( view == $scope.currentView ) {
      return true;
    }
    return false;
  };
  $scope.changeView = function( newView, newSubview, updateLocation ) {
    if( newView != $scope.currentView || newSubview != $scope.currentSubview ) {
      $scope.currentView = newView;
      // note: subview is being preserved on view changes
      if( newSubview ) { $scope.currentSubview = newSubview; }
      if( $scope.observations && $scope.observations ) {
        $scope.observations = $scope.observations.slice( 0, 40 );
      }
      if( updateLocation !== false ) {
        $scope.updateBrowserLocation( );
      }
    }
  };
  $scope.updateParams = function( newParams ) {
    $scope.params = $.extend($scope.params, newParams);
    if (newParams.view) {
      $scope.changeView(newParams.view);
    };
  };
  $scope.searchAndUpdateStats = function( options ) {
    $scope.pagination = { page: 1 };
    $scope.numberTaxaShown = 20;
    $scope.numberIdentifiersShown = 20;
    $scope.numberObserversShown = 20;
    options = options || { };
    $scope.updateBrowserLocation( );
    var processedParams = shared.processParams( _.extend( { },
      $scope.params, { page: $scope.pagination.page } ), $scope.possibleFields);
    // recording there was some location in the search. That will be used
    // to hide the `Redo Search` button until the map moves
    if( processedParams.place_id || processedParams.swlat ) {
      $scope.justSelectedLocation = true;
    }
    $scope.lastSearchTime = new Date( ).getTime( );
    ObservationsFactory.search( processedParams ).then( function( response ) {
      $scope.lastSearchTime = new Date( ).getTime( );
      $scope.resetStats( );
      $scope.totalObservations = response.data.total_results;
      $scope.observations = ObservationsFactory.responseToInstances( response );
      ObservationsFactory.stats( processedParams ).then( function( response ) {
        $scope.totalObservers = response.data.observer_count;
        $scope.totalIdentifiers = response.data.identifier_count;
      });
      ObservationsFactory.speciesCount( processedParams ).then( function( response ) {
        $scope.totalSpecies = response.data.leaf_count;
      });
      ObservationsFactory.speciesCounts( processedParams ).then( function( response ) {
        $scope.taxa = _.map( response.data, function( r ) {
          var t = new iNatModels.Taxon( r.taxon );
          t.resultCount = r.count;
          return t;
        });
      });
      ObservationsFactory.identifiers( processedParams ).then( function( response ) {
        $scope.identifiers = _.map( response.data, function( r ) {
          var u = new iNatModels.User( r.user );
          u.resultCount = r.count;
          return u;
        });
      });
      ObservationsFactory.observers( processedParams ).then( function( response ) {
        $scope.observers = _.map( response.data, function( r ) {
          var u = new iNatModels.User( r.user );
          u.resultCount = r.count;
          return u;
        });
      });
    });
  };
  // simple "pagination" of results already fetched, so we're not
  // rendering too many DOM elements, which need images fetched
  $scope.showMoreTaxa = function( ) {
    $scope.numberTaxaShown += 20;
  };
  $scope.showMoreIdentifiers = function( ) {
    $scope.numberIdentifiersShown += 20;
  };
  $scope.showMoreObservers = function( ) {
    $scope.numberObserversShown += 20;
  };
  $scope.showMoreObservations = function( ) {
    $scope.pagination = $scope.pagination || { };
    if( !$scope.pagination.page ) { return; }
    if( $scope.pagination.busy === true ) { return; }
    if( $scope.pagination.finished === true ) { return; }
    $scope.pagination.page += 1;
    $scope.pagination.busy = true;
    var processedParams = shared.processParams(
      _.extend( { }, $scope.params, { page: $scope.pagination.page } ), $scope.possibleFields);
    ObservationsFactory.search( processedParams ).then( function( response ) {
      if( response.data.total_results <= ( response.data.page * response.data.per_page ) ) {
        $scope.pagination.finished = true;
      }
      $scope.observations = $scope.observations.concat(
        ObservationsFactory.responseToInstances( response ));
      $scope.pagination.busy = false;
    });
  };
  $scope.matchUrlState = function( ) {
    var urlParams = $location.search( );
    if( urlParams.view && _.contains( $scope.possibleViews, urlParams.view ) ) {
      $scope.currentView = urlParams.view;
    }
    if( $scope.currentView && $scope.possibleSubviews[ $scope.currentView ] &&
        _.contains( $scope.possibleSubviews[ $scope.currentView ], urlParams.subview ) ) {
      $scope.currentSubview = urlParams.subview;
    }
    $scope.changeView( urlParams.view, urlParams.subview, false );
    $scope.currentView = $scope.currentView || $scope.defaultView;
    $scope.currentSubview = $scope.currentSubview || $scope.defaultSubview;
  };
  $scope.showNearbyPlace = function( place ) {
    $rootScope.$emit( "showNearbyPlace", place );
  };
  $scope.hideNearbyPlace = function( place ) {
    $rootScope.$emit( "hideNearbyPlace", place );
  };
  $scope.filterByPlace = function( place ) {
    $rootScope.$emit( "hideNearbyPlace" );
    $scope.selectedPlace = place;
    $scope.removeSelectedBounds( );
  };
  $scope.filterByBounds = function( ) {
    $rootScope.$emit( "hideNearbyPlace" );
    $scope.removeSelectedPlace( );
    $rootScope.$emit( "updateParamsForCurrentBounds" );
  };
  $scope.removeSelectedPlace = function( ) {
    $scope.selectedPlace = null;
    $scope.justSelectedLocation = false;
  };
  $scope.removeSelectedBounds = function( ) {
    $scope.params.swlng = null;
    $scope.params.swlat = null;
    $scope.params.nelng = null;
    $scope.params.nelat = null;
    $scope.justSelectedLocation = false;
  };
  $scope.orderBy = function( order ) {
    if ($scope.params.order_by == order) {
      $scope.params.order = ($scope.params.order == 'asc' ? 'desc' : 'asc');
    } else {
      $scope.params.order_by = order;
      $scope.params.order = 'desc';
    }
  };
  $scope.setupFilterToggle = function( ) {
    // I started using the default bootstrap dropdown to manage the filter opening,
    // but it assumes all clicks in the dropdown should close the dropdown, so I had
    // to not use the boostrap javascript there and do it myself
    $( "#filter-container .dropdown-toggle" ).click( function( ) {
      $( this ).parent( ).toggleClass( "open" );
    });
    // closing the filter box
    $( "body" ).on( "click", function( e ) {
      if( !$( "#filter-container" ).is( e.target ) &&
          $( "#filter-container" ).has( e.target ).length === 0 &&
          $( ".open" ).has( e.target ).length === 0 &&
          $( e.target ).parents('.ui-datepicker').length === 0 &&
          $( e.target ).parents('.ui-datepicker-header').length === 0 &&
          $( e.target ).parents('.ui-multiselect-menu').length === 0
        ) {
        $( "#filter-container" ).removeClass( "open" );
      };
    });
  };
  $scope.setupDatepicker = function( ) {
    $('.date-picker').datepicker({
      yearRange: "c-100:c+0",
      maxDate: '+0d',
      constrainInput: false,
      firstDay: 0,
      changeFirstDay: false,
      changeMonth: true,
      changeYear: true,
      dateFormat: 'yy-mm-dd',
      showTimezone: false,
      closeText: I18n.t('date_picker.closeText'),
      currentText: I18n.t('date_picker.currentText'),
      prevText: I18n.t('date_picker.prevText'),
      nextText: I18n.t('date_picker.nextText'),
      monthNames: eval(I18n.t('date_picker.monthNames')),
      monthNamesShort: eval(I18n.t('date_picker.monthNamesShort')),
      dayNames: eval(I18n.t('date_picker.dayNames')),
      dayNamesShort: eval(I18n.t('date_picker.dayNamesShort')),
      dayNamesMin: eval(I18n.t('date_picker.dayNamesMin'))
    });
  };
  $scope.setupPlaceSearchbox = function( ) {
    $scope.placeSearchBox = new google.maps.places.SearchBox(
      document.getElementById( "place_name" ));
    $scope.placeSearchBox.addListener( "places_changed", function( ) {
      var places = $scope.placeSearchBox.getPlaces( );
      if( places.length != 1 ) { return; }
      var place = places[ 0 ];
      if( !place.geometry ) { return; }
      $scope.searchedPlace = place;
      $scope.focusOnSearchedPlace( );
    });
  };
  $scope.focusOnSearchedPlace = function( ) {
    if( $scope.searchedPlace ) {
      // setting a timer for automatching the searched place to a known place
      $scope.placeLastSearched = new Date( ).getTime( );
      $scope.attemptAutoNearbySelection = true;
      $scope.mapCenter = null;
      $scope.mapZoom = null;
      $scope.mapBounds = null;
      if( $scope.searchedPlace.geometry.viewport ) {
        $scope.mapBounds = $scope.searchedPlace.geometry.viewport;
        $scope.mapCenter = $scope.searchedPlace.geometry.location;
        $scope.mapZoom = null;
      } else {
        $scope.mapCenter = $scope.searchedPlace.geometry.location;
        $scope.mapZoom = 15;
        $scope.mapBounds = null;
      }
      $rootScope.$emit( "alignMap" );
    }
  };
  // when the place search input changes, delete the stored searched place
  $scope.$watch( "placeSearch", function( ) {
    $scope.searchedPlace = null;
  });
  $scope.setupMiltiselects = function( ) {
    $( "#filters select[multiple]" ).multiselect({
      minWidth: 150,
      checkAllText: I18n.t( "all" ),
      uncheckAllText: I18n.t( "none" )
    });
  };
  $scope.setupTaxonAutocomplete = function( ) {
    $( "#filters input[name='taxon_name']" ).taxonAutocomplete({
      taxon_id_el: $( "#filters input[name='taxon_id']" ),
      afterSelect: function( result ) {
        $scope.params.taxon_id = result.item.id;
        $scope.searchAndUpdateStats( );
      },
      afterUnselect: function( ) {
        if( $scope.params.taxon_id != null ) {
          $scope.params.taxon_id = null;
          $scope.searchAndUpdateStats( );
        }
      }
    });
  };
  $scope.determineFieldNames = function( ) {
    _.map( $( "#filters input,select" ), function( input ) {
      var name = $( input ).attr( "ng-model" ) || input.name;
      name = name.replace( "params.", "" );
      $scope.possibleFields.push( name );
    });
    $scope.defaultProcessedParams = shared.processParams( $scope.defaultParams, $scope.possibleFields );
  };
  $scope.preInitialize( );
}]);


application.controller( "MapController", [ "PlacesFactory", "shared", "$scope", "$rootScope", "$anchorScroll",
function( PlacesFactory, shared, $scope, $rootScope, $anchorScroll ) {
  $rootScope.$on( "updateParamsForCurrentBounds", function( ) {
    $scope.updateParamsForCurrentBounds( );
  });
  $rootScope.$on( "offsetCenter", function( event, left, up ) {
    shared.offsetCenter({ map: $scope.map, left: left, up: up }, function( center ) {
      $scope.map.setCenter( center );
    });
  });
  $scope.setupMap = function( ) {
    if( $scope.map ) { return; }
    $( "#map" ).taxonMap({
      urlCoords: true,
      mapType: google.maps.MapTypeId.TERRAIN,
      showLegend: true,
      showAllLayer: false,
      disableFullscreen: true,
      mapTypeControl: false
    });
    $scope.map = $( "#map" ).data( "taxonMap" );
    // waiting a bit after creating the map to initialize the layers
    // to avoid issues with map aligning, letting the browser catch up
    setTimeout( function( ) {
      if( !$scope.mapLayersInitialized ) {
        $scope.setMapLayers( true );
        // more delays before enabling onMoves so setMapLayers
        // can finish aligning the map if it needs to
        setTimeout( function( ) {
          $scope.map.addListener( "dragstart", function( ) { $scope.delayedOnMove( ); });
          $scope.map.addListener( "center_changed", function( ) { $scope.delayedOnMove( ); });
          $scope.map.addListener( "zoom_changed", function( ) { $scope.delayedOnMove( ); });
        }, 500 );
      }
    }, 300);
  }
  $scope.updateParamsForCurrentBounds = function( ) {
    var bounds = $scope.$parent.viewing( "observations", "map" ) ?
      $scope.map.getBounds( ) : $scope.$parent.mapBounds;
    if( !bounds ) { return; }
    var ne     = bounds.getNorthEast( ),
        sw     = bounds.getSouthWest( );
    $scope.$parent.params.swlng = sw.lng( );
    $scope.$parent.params.swlat = sw.lat( );
    $scope.$parent.params.nelng = ne.lng( );
    $scope.$parent.params.nelat = ne.lat( );
    $scope.$parent.selectedPlace = null;
  };
  $rootScope.$on( "searchForNearbyPlaces", function( event ) {
    $scope.searchForNearbyPlaces( );
  });
  $scope.searchForNearbyPlaces = function( ) {
    if( $scope.$parent.placeSearchBox && $scope.map ) {
      $scope.$parent.placeSearchBox.setBounds( $scope.map.getBounds( ) );
    }
    // search a little left of center
    shared.offsetCenter({ map: $scope.map, left: -130, up: 0 }, function( center ) {
      var lat = 0,
          lng = 0,
          admin_level = 0,
          boundsDistance = 1000000;
      // there may not be a center if the map hasn't loaded yet
      if( center ) {
        var lat = center.lat( );
        var lng = center.lng( );
        var b = $scope.map.getBounds( );
        // search within a radius roughly matching the viewport
        var boundsDistance = google.maps.geometry.spherical.computeDistanceBetween(
          b.getNorthEast( ), b.getSouthWest( ) ) * 0.4;
        var admin_level = 0;
        // search for places based on zoom_level/admin_level
        var zoom = $scope.map.getZoom( );
        if( zoom <= 6 ) { boundsDistance = null; }
        if( zoom >= 6 ) { admin_level = 1; }
        if( zoom >= 9 ) { admin_level = 2; }
        if( zoom >= 11 ) { admin_level = 3; }
      }
      PlacesFactory.nearby( { lat: lat, lng: lng, admin_level: admin_level, radius: boundsDistance }).then( function( response ) {
        places = PlacesFactory.responseToInstances( response );
        if( places.length > 0 ) {
          $scope.$parent.nearbyPlaces = places;
          var timeSinceSearch = new Date( ).getTime( ) - $scope.placeLastSearched;
          if( $scope.attemptAutoNearbySelection && timeSinceSearch < 1000 ) {
            // check the nearby places for a match to searches in the last second
            if( $scope.$parent.nearbyPlaces.length > 0 ) {
              _.each( $scope.$parent.nearbyPlaces, function( p ) {
                if( !$scope.attemptAutoNearbySelection || !$scope.searchedPlace ) { return; }
                var searchedName = ( _.isObject( $scope.searchedPlace ) ?
                  $scope.searchedPlace.name : $scope.searchedPlace ).toLowerCase( );
                if( shared.stringStartsWith( p.name, searchedName ) || shared.stringStartsWith( searchedName, p.name ) ) {
                  $scope.$parent.filterByPlace( p );
                  $scope.$parent.attemptAutoNearbySelection = false;
                  return;
                }
              });
            }
            // no good matches from nearby places, so filter by the searched bounds
            if( $scope.$parent.attemptAutoNearbySelection ) {
              $scope.updateParamsForCurrentBounds( );
            }
            $scope.$parent.justSelectedLocation = true;
          }
        } else { $scope.$parent.nearbyPlaces = [ ]; }
        $scope.$parent.attemptAutoNearbySelection = false;
      });
    });
  };
  $rootScope.$on( "showNearbyPlace", function( event, place ) {
    if( $scope.nearbyPlaceLayer ) { $scope.nearbyPlaceLayer.setMap( null ); }
    $scope.nearbyPlaceLayer = null;
    $scope.nearbyPlaceLayer = new google.maps.Data({ style: {
      strokeColor: '#d77a3b',
      strokeOpacity: 0.6,
      strokeWeight: 4,
      fillOpacity: 0
    }});
    var geojson = { type: "Feature", geometry: place.geometry_geojson };
    $scope.nearbyPlaceLayer.addGeoJson( geojson );
    $scope.nearbyPlaceLayer.setMap( $scope.map );
  });
  $rootScope.$on( "hideNearbyPlace", function( ) {
    if( $scope.nearbyPlaceLayer ) { $scope.nearbyPlaceLayer.setMap( null ); }
    $scope.nearbyPlaceLayer = null;
  });
  $rootScope.$on( "setMapLayers", function( event, align) {
    $scope.setMapLayers( align );
  });
  $rootScope.$on( "alignMap", function( ) {
    $scope.alignMap( );
  });
  $scope.lastMoveTime = 0;
  $scope.delayedOnMove = function( ) {
    // show the `Redo Search` button when the map moves
    $scope.showRedoSearchButton( );
    var time = new Date( ).getTime( );
    $scope.lastMoveTime = time;
    setTimeout( function( ) {
      // only perform one nearby place search, once
      // the map has stopped moving for a half second
      if( $scope.lastMoveTime === time ) {
        $rootScope.$emit( "searchForNearbyPlaces" );
      }
    }, 500 )
  };
  $scope.showRedoSearchButton = function( ) {
    var time = new Date( ).getTime( );
    // the map can align after searches and we don't want that
    // to quickly reenable the `Redo Search` button. Wait a
    // half second after searches to prevent that
    if( $scope.$parent.lastSearchTime && time - $scope.$parent.lastSearchTime < 500 ) {
      return;
    } else { $scope.$parent.lastSearchTime = null; }
    if( $scope.$parent.justSelectedLocation ) {
      $scope.$parent.justSelectedLocation = false;
      if(!$scope.$parent.$$phase) { $scope.$parent.$digest( ); }
    }
  };
  $scope.alignMap = function( ) {
    if( $scope.mapLayersInitialized ) {
      if( $scope.$parent.mapBounds ) {
        $scope.map.fitBounds( $scope.$parent.mapBounds );
        $scope.map.setZoom( $scope.map.getZoom( ) + 1 );
      } else if( $scope.$parent.mapCenter ) {
        $scope.map.setCenter( $scope.$parent.mapCenter );
        $scope.map.setZoom( $scope.$parent.mapZoom );
      } else if( $scope.selectedPlaceLayer ) {
        var bounds = new google.maps.LatLngBounds();
        // extend the bounds to encompass all features in the polygon
        $scope.selectedPlaceLayer.forEach(function(feature) {
          shared.processPoints( feature.getGeometry( ), bounds.extend, bounds );
        });
        $scope.map.fitBounds( bounds );
        if( $scope.$parent.selectedPlace ) {
          // move the map to a little left of center
          $rootScope.$emit( "offsetCenter", 130, 0 );
        } else {
          $scope.map.setZoom( $scope.map.getZoom( ) + 1 );
        }
      }
      $scope.$parent.mapNeedsAligning = false;
    }
    $rootScope.$emit( "searchForNearbyPlaces" );
  };
  $scope.setMapLayers = function( align ) {
    if( !$scope.map ) { return };
    if( !$scope.$parent.parametersInitialized ) { return };
    window.inatTaxonMap.removeObservationLayers( $scope.map, { title: "Observations" } );
    var layerParams = shared.processParams( $scope.params, $scope.possibleFields );
    window.inatTaxonMap.addObservationLayers( $scope.map, {
      title: "Observations",
      mapStyle: _.isEqual( $scope.$parent.defaultProcessedParams, layerParams ) ? "summary" : "colored_heatmap",
      observationLayers: [ layerParams ]
    });
    // fully remove any existing data layer
    if( $scope.selectedPlaceLayer ) { $scope.selectedPlaceLayer.setMap( null ); }
    $scope.selectedPlaceLayer = null;
    if( $scope.$parent.selectedPlace || $scope.params.swlat ) {
      $scope.selectedPlaceLayer = new google.maps.Data({ style: {
        strokeColor: '#d77a3b',
        strokeOpacity: 0.75,
        strokeWeight: 5,
        fillOpacity: 0
      }});
      // draw the polygon for the current place
      if( $scope.$parent.selectedPlace ) {
        var c = { type: "Feature",
          geometry: $scope.$parent.selectedPlace.geometry_geojson };
        $scope.selectedPlaceLayer.addGeoJson( c );
        $scope.selectedPlaceLayer.setMap( $scope.map );
      }
      // draw the filter bounding box
      else if( $scope.params.swlat && $scope.params.swlng &&
          $scope.params.nelat && $scope.params.nelng ) {
        $scope.selectedPlaceLayer.addGeoJson({
          type: "Feature",
          geometry: {
            type: "Polygon",
            coordinates: [ [
              [ parseFloat( $scope.params.swlng ), parseFloat( $scope.params.swlat ) ],
              [ parseFloat( $scope.params.nelng ), parseFloat( $scope.params.swlat ) ],
              [ parseFloat( $scope.params.nelng ), parseFloat( $scope.params.nelat ) ],
              [ parseFloat( $scope.params.swlng ), parseFloat( $scope.params.nelat ) ],
              [ parseFloat( $scope.params.swlng ), parseFloat( $scope.params.swlat ) ]
            ] ]
          }
        });
        $scope.selectedPlaceLayer.setMap($scope.map)
      }
    }
    $scope.mapLayersInitialized = true;
    if( align ) { $scope.alignMap( ); }
  };
}]);
