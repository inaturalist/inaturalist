var application =  angular.module( "ObservationSearch", [
  "infinite-scroll",
  "templates",
  "ehFilters", // angular-capitalize
  "iNatAPI",
  "ui.bootstrap",
  "angularMoment",
  "truncate"
]);

// Load translations for moment if available
// http://stackoverflow.com/a/22965260
if (I18n.translations[I18n.locale] && 
    I18n.translations[I18n.locale].momentjs && 
    I18n.translations[I18n.locale].momentjs.shortRelativeTime) {
  moment.locale(I18n.locale, {
    relativeTime: I18n.translations[I18n.locale].momentjs.shortRelativeTime
  })
}

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
          }, 100);
        }
      });
      // the observation div on the map is a scrollable div in a scrollable page
      // make sure that when you scroll to the botton of that div, the page
      // doesn't start scrolling down
      $( "#obs" ).isolatedScroll( );
    }
  };
});

application.config( [ "$locationProvider", function($locationProvider) {
  $locationProvider.html5Mode({
    enabled: true
  });
}]);

if( TIMEZONE ) {
  application.constant( "angularMomentConfig", { timezone: TIMEZONE });
}

application.controller( "SearchController", [ "ObservationsFactory", "PlacesFactory",
"TaxaFactory", "shared", "$scope", "$rootScope", "$location", "$anchorScroll", "$uibPosition",
function( ObservationsFactory, PlacesFactory, TaxaFactory, shared, $scope, $rootScope, $location, $anchorScroll ) {
  $scope.currentUser = CURRENT_USER;
  $scope.shared = shared;
  $scope.possibleViews = [ "observations", "species", "identifiers", "observers" ];
  $scope.possibleSubviews = { observations: [ "map", "grid", "table" ] };
  $scope.possibleFields = [ "iconic_taxa", "month", "swlat", "swlng",
    "nelat", "nelng", "place_id", "taxon_id", "page", "view", "subview",
    "locale", "preferred_place_id" ];
  $scope.defaultView = "observations";
  $scope.defaultSubview = "map";
  $rootScope.mapType = "map";
  $rootScope.mapLabels = true;
  $rootScope.mapTerrain = false;
  $scope.defaultParams = {
    verifiable: true,
    order_by: "observations.id",
    order: "desc",
    page: 1
  };
  $scope.mapBounds = new google.maps.LatLngBounds(
    new google.maps.LatLng( -80, -179 ),
    new google.maps.LatLng( 80, 179 ));
  $scope.nearbyPlaces = null;
  $scope.hideRedoSearch = true;
  $scope.taxonInitialized = false;
  $scope.placeInitialized = false;
  $scope.filtersInitialized = false;
  $scope.parametersInitialized = false;
  $scope.moreFiltersHidden = true;
  $scope.moreFiltersToWatch = [ "params.user_id", "params.project_id", 
    "params.photo_license", "params.reviewed", "params.created_on", 
    "params.created_month", "params.created_d1", "params.created_d2",
    "clickedMoreFiltersOpen" ];

  $scope.$watchGroup(['mapType', 'mapLabels', 'mapTerrain'], function() {
    $rootScope.$emit( "setMapType", $scope.mapType, $scope.mapLabels, $scope.mapTerrain );
  });

  // this is the first block to run when the page loads
  $scope.preInitialize = function( ) {
    $scope.resetStats( );         // all stats read ---
    $scope.setInitialParams( );   // set params from URL, lookup place and taxon
    $scope.matchUrlState( );      // set the right view
  };

  // once the initial state is prepared from the URL and params loaded
  $scope.afterParametersInitialized = function( ) {
    if( $scope.taxonInitialized && $scope.placeInitialized &&
        $scope.filtersInitialized && !$scope.parametersInitialized ) {
      // fetch the observations
      $scope.searchAndUpdateStats({ browserStateOnly: true });
      // set proper map layers for the search and orient the map
      $rootScope.$emit( "setMapLayers", true );
      // now we watch for param changes
      $scope.watchParams( );
      $scope.parametersInitialized = true;
    }
  };
  // any time an initialization step finishes, attempt afterInitialize
  $scope.$watchGroup([ "taxonInitialized", "filtersInitialized",
                       "placeInitialized" ], function( ) {
    $scope.afterParametersInitialized( );
  });
  // runs when the filters template has been rendered
  $scope.onFiltersLoad = function( ) {
    $scope.setupFilterToggle( );
    $scope.setupDatepicker( );
    $scope.setupPlaceSearchbox( );
    $scope.determineFieldNames( );
    $scope.setupTaxonAutocomplete( );
    $scope.setupInatPlaceAutocomplete( );
    $scope.setupUserAutocomplete( );
    $scope.setupProjectAutocomplete( );
    $scope.setupBrowserStateBehavior( );
    $scope.filtersInitialized = true;
    // someone searched with taxon_name, but no mathing taxon was found,
    // so focus and click on the field to present the autocomplete results
    if( $scope.params.taxon_name && !SELECTED_TAXON_ID ) {
      $( "#filters input[name='taxon_name']" ).focus( );
      $( "#filters input[name='taxon_name']" ).click( );
    }
  };
  $scope.resetStats = function( ) {
    _.each([ "totalObservations", "totalSpecies", "totalObservers", "totalIdentifiers" ], function( k ) {
      $scope[ k ] = "--";
    });
    _.each([ "taxa", "identifiers", "observers" ], function( k ) {
      $scope[ k ] = [ ];
    });
    if(!$scope.$$phase) { $scope.$digest( ); }
  };
  $scope.resetParams = function( ) {
    var resetParams = _.extend( { }, $scope.defaultParams );
    if( $scope.preferredPlaceObject ) {
      resetParams.place_id = $scope.preferredPlaceObject.id;
    }
    $scope.params = _.extend( { }, $scope.defaultParams );
    // reset taxon autocomplete
    $( "#filters input[name='taxon_name']" ).trigger( "resetAll" );
    // reset place autocomplete
    $scope.selectedPlace = $scope.preferredPlaceObject;
    $scope.searchedPlace = null;
    $scope.placeSearch = null;
    $scope.closeFilters();
  };
  $scope.closeFilters = function( ) {
    $( "#filter-container" ).removeClass( "open" );
  };
  $scope.watchParams = function( ) {
    // params may change but not affect the results
    // for example DateType will change with the different date options
    $scope.$watch( "params", function(newValue, oldValue ) {
      $scope.processedParams = ObservationsFactory.processParamsForAPI( $scope.params, $scope.possibleFields );
      if ( CURRENT_USER ) {
        $scope.showingViewerObservations = (
          ($scope.processedParams.user_id == CURRENT_USER.id) || 
          ($scope.processedParams.user_id == CURRENT_USER.login)
        );
      }
      if( _.isEqual( newValue, oldValue ) ) { return; }
      // if any of the filters change we want to reset the page to 1.
      // when pagination, the page will change, so if the page doesn't
      // change, then the user is changing another filter, so go to page 1
      if( newValue.page === oldValue.page ) {
        $scope.params.page = 1;
      }
    }, true);
    // changes in processedParams are what initiate searches
    $scope.$watch( "processedParams", function( before, after ) {
      if( _.isEqual( before, after ) ) { return; }
      // when paginating we do want to set processedParams, but we don't
      // want to query for the stats again as they will stay the same
      if( $scope.skipParamChange ) {
        $scope.skipParamChange = false;
        return;
      }
      // we don't want to set the location on page load, it will already be set
      $scope.searchAndUpdateStats({ skipSetLocation: $scope.goingBack });
      $rootScope.$emit( "setMapLayers", $scope.alignMapOnSearch );
      // restore some one-time search settings
      $scope.alignMapOnSearch = false;
      $scope.goingBack = false;
    }, true);
  };
  $scope.toggleMoreFilters = function( ) {
    $scope.clickedMoreFiltersOpen = $scope.clickedMoreFiltersOpen == true ? false : true;
  };
  // watch more filters to dermine whether to show them or not
  $scope.$watchGroup( $scope.moreFiltersToWatch, function(newValues, oldValues, scope) {
    var pageInit = _.isEqual( newValues, oldValues );
    if ( $scope.clickedMoreFiltersOpen ) {
      scope.moreFiltersHidden = false;
      return;
    } else if ( $scope.clickedMoreFiltersOpen == false ) {
      scope.moreFiltersHidden = true;
      return;
    }
    var moreFiltersHidden = true;
    _.each( scope.moreFiltersToWatch, function( f ) {
      if ( newValues[ $scope.moreFiltersToWatch.indexOf( f ) ] ) {
        moreFiltersHidden = false;
      };
    } );
    if ( pageInit && $scope.clickedMoreFiltersOpen == null && !moreFiltersHidden ) {
      $scope.clickedMoreFiltersOpen = true;
    };
    scope.moreFiltersHidden = moreFiltersHidden;
  } );
  $scope.$watch( "params.user_id", function( ) {
    $scope.updateUserAutocomplete( );
  });
  $scope.$watch( "params.project_id", function( ) {
    $scope.updateProjectAutocomplete( );
  });
  // watch for place selections, unselections
  $scope.$watch( "selectedPlace", function( ) {
    if( $scope.selectedPlace && $scope.selectedPlace.id ) {
      if( $scope.params.place_id != $scope.selectedPlace.id ) {
        $scope.mapBounds = null;
        $scope.mapBoundsIcon = null;
        $scope.alignMapOnSearch = true;
        $scope.params.place_id = $scope.selectedPlace.id;
        $scope.updatePlaceAutocomplete( );
      }
    } else if( !_.isArray( $scope.params.place_id) ) {
      $scope.alignMapOnSearch = false;
      $scope.params.place_id = "any";
      $scope.updatePlaceAutocomplete( );
    }
  });
  $scope.initializeTaxonParams = function( ) {
    if( $scope.params.taxon_id ) {
      $scope.params.taxon_id = parseInt( $scope.params.taxon_id );
    }
    if( $scope.params.taxon_id ) {
      // load taxon auto name and photo for autocomplete. Send locale
      // params to we load the right taxon name for the users's prefs
      TaxaFactory.show( $scope.params.taxon_id, iNaturalist.localeParams( ) ).
        then( function( response ) {
          taxa = TaxaFactory.responseToInstances( response );
          if( taxa.length > 0 ) {
            $scope.selectedTaxon = taxa[ 0 ];
          }
          $scope.updateTaxonAutocomplete( );
          $scope.taxonInitialized = true;
        }
      );
    } else {
      // this will remove the autocomlete image since there's no taxon
      $scope.updateTaxonAutocomplete( );
      $scope.taxonInitialized = true;
    }
  };
  $scope.initializePlaceParams = function( ) {
    $scope.params.place_id = $scope.params["place_id[]"] || $scope.params.place_id;
    if( _.isString( $scope.params.place_id ) ) {
      $scope.params.place_id = _.filter( $scope.params.place_id.split(","), _.identity );
    }
    if( _.isArray( $scope.params.place_id ) && $scope.params.place_id.length === 1 ) {
      $scope.params.place_id = $scope.params.place_id[0];
    }
    if( $scope.params.place_id && !_.isArray( $scope.params.place_id ) ) {
      $scope.params.place_id = parseInt( $scope.params.place_id );
    }
    if( $scope.params.place_id && !_.isArray( $scope.params.place_id ) ) {
      // load place name and polygon from ID
      PlacesFactory.show( $scope.params.place_id ).then( function( response ) {
        places = PlacesFactory.responseToInstances( response );
        if( places.length > 0 ) {
          if( PREFERRED_PLACE && places[ 0 ].id === PREFERRED_PLACE.id ) {
            $scope.preferredPlaceObject = places[ 0 ];
          }
          $scope.filterByPlace( places[ 0 ] );
        }
        $scope.placeInitialized = true;
      });
    } else {
      // otherwise set the starting mapBounds
      if( $scope.params.swlat && $scope.params.swlng &&
          $scope.params.nelat && $scope.params.nelng ) {
        $scope.mapBounds = new google.maps.LatLngBounds(
            new google.maps.LatLng( $scope.params.swlat, $scope.params.swlng ),
            new google.maps.LatLng( $scope.params.nelat, $scope.params.nelng ));
      } else if( $scope.params.lat && $scope.params.lng ) {
        $scope.mapBounds = new google.maps.LatLngBounds(
          new google.maps.LatLng( parseFloat( $scope.params.lat ) - 0.1,
            parseFloat( $scope.params.lng ) - 0.1 ),
          new google.maps.LatLng( parseFloat( $scope.params.lat ) + 0.1,
            parseFloat( $scope.params.lng ) + 0.1 ));
      }
      $scope.placeInitialized = true;
    }
  };
  // set params from the URL and lookup any Taxon or Place selections
  $scope.setInitialParams = function( ) {
    var initialParams = _.extend( { }, $scope.defaultParams, $location.search( ) );
    if( initialParams.verifiable === "true" ) {
      initialParams.verifiable = true;
    }
    // turning the key taxon_ids[] into taxon_ids
    if( initialParams["taxon_ids[]"] ) {
      initialParams.taxon_ids = initialParams["taxon_ids[]"];
      delete initialParams["taxon_ids[]"];
    }
    // setting _iconic_taxa for the iconic taxa filters, (e.g { Chromista: true })
    if( initialParams.iconic_taxa ) {
      initialParams._iconic_taxa = _.object( _.map( initialParams.iconic_taxa.split(","),
        function( n ) { return [ n, true ]; }
      ));
    }
    // set the default user or site place_id
    if( PREFERRED_PLACE && !ObservationsFactory.hasSpatialParams( initialParams ) ) {
      initialParams.place_id = PREFERRED_PLACE.id;
    }
    if( PREFERRED_SUBVIEW && !initialParams.subview ) {
      $scope.currentSubview = PREFERRED_SUBVIEW;
    }
    // use the current user's id as the basis for the `reviewed` param
    if( !_.isUndefined( initialParams.reviewed ) && !initialParams.reviewed_by && CURRENT_USER ) {
      initialParams.viewer_id = CURRENT_USER.id;
    }
    // a taxon_name param was provided, and a match was found,
    // so use taxon_id and remove taxon_name
    if( initialParams.taxon_name && SELECTED_TAXON_ID && !initialParams.taxon_id ) {
      initialParams.taxon_id = SELECTED_TAXON_ID;
      delete initialParams.taxon_name;
    }
    // months from URLs need to be turned into arrays
    if( initialParams.month ) { initialParams.month = initialParams.month.split( "," ); }
    $scope.params = initialParams;
    $scope.initializeTaxonParams( );
    $scope.initializePlaceParams( );
  };
  $scope.extendBrowserLocation = function( options ) {
    var params = _.extend( { }, $location.search( ), options );
    params = _.omit( params, function( value, key, object ) {
      return _.isEmpty( value) && !_.isBoolean( value ) && !_.isNumber( value );
    });
    return "?" + $.param( params );
  };
  $scope.updateBrowserLocation = function( options ) {
    options = options || { };
    if( options.skipSetLocation ) { return; }
    var newParams = [ ];
    _.each( $scope.params, function( value, param ) {
      // don't show default params in the URL
      if( $scope.defaultParams.hasOwnProperty( param ) &&
          value === $scope.defaultParams[ param ] ) {
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
    // default to initial state
    var currentState = { };
    var currentSearch = { };
    if( !_.isEmpty( newParams ) ) {
      var urlParams = ObservationsFactory.processParams( _.object( newParams ), $scope.possibleFields );
      urlParams = _.mapObject( urlParams, function( v, k ) {
        // arrays turned to comma-delimited lists for URLs
        if( _.isArray( v ) ) { return v.join(","); }
        // allow `photos=any` when the default value of true is changed
        if( $scope.defaultParams[ k ] === true && v !== true ) { v = "any"; }
        return v;
      });
      // never show `viewer_id` in the browser location
      delete urlParams.viewer_id;
      // add to the state a few params that don't appear in the URL
      var stateParams = _.extend( { }, urlParams, {
        dateType: $scope.params.dateType,
        createdDateType: $scope.params.createdDateType
      });
      // prepare current settings to store in browser state history
      currentState = { params: stateParams,
        selectedPlace: JSON.stringify( $scope.selectedPlace ),
        selectedTaxon: JSON.stringify( $scope.selectedTaxon ),
        mapBounds: $scope.mapBounds ? $scope.mapBounds.toJSON( ) : null,
        mapBoundsIcon: $scope.mapBoundsIcon };
      currentSearch = urlParams;
    }

    $scope.numFiltersSet = _.keys( currentSearch ).length
    var skippableParams = [ 'view', 'subview', 'taxon_id', 'place_id',
      'swlat', 'swlng', 'nelat', 'nelng', 'page' ];
    for (var i = skippableParams.length - 1; i >= 0; i--) {
      if ( currentSearch[ skippableParams[i] ] ) {
        $scope.numFiltersSet -= 1;
      }
    }
    if ( currentSearch.iconic_taxa && currentSearch.iconic_taxa.split(',').length > 1 ) {
      $scope.numFiltersSet += currentSearch.iconic_taxa.split(',').length - 1 ; 
    }

    if( options.browserStateOnly ) {
      $scope.initialBrowserState = currentState;
    } else {
      $location.state( currentState );
      if( options.replace ) {
        $location.search( currentSearch ).replace( );
      } else {
        $location.search( currentSearch );
      }
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
  $scope.changeView = function( newView, newSubview, options ) {
    if( newView != $scope.currentView || newSubview != $scope.currentSubview ) {
      $scope.currentView = newView;
      // note: subview is being preserved on view changes
      if( newSubview ) {
        $scope.currentSubview = newSubview;
        updateSession({ prefers_observations_search_subview: newSubview });
      }
      $scope.updateBrowserLocation( options );
    }
  };
  $scope.updateParams = function( newParams ) {
    var timeout = 10;
    if( newParams.view ) {
      $scope.changeView( newParams.view, null, { skipSetLocation: true } );
      $anchorScroll( );
      if( newParams.view == "observations" && $scope.currentSubview == "map" ) {
        // the map view will need a moment before being able to align properly
        timeout = 300;
      }
    }
    setTimeout(function( ) {
      var reinitializeTaxon = ( newParams.taxon_id != $scope.params.taxon_id );
      $scope.alignMapOnSearch = true;
      $scope.params = _.extend( { }, $scope.params, newParams );
      // update the taxon autocomplete image
      if( reinitializeTaxon ) { $scope.initializeTaxonParams( ); }
    }, timeout);
  };
  $scope.searchingStopped = function( ) {
    if( !$scope.pagination ) { return false; }
    return $scope.pagination.stopped && !$scope.pagination.searching;
  };
  $scope.noObservations = function( ) {
    if( !$scope.searchingStopped( ) ) { return false; }
    return $scope.observations.length == 0;
  };
  $scope.noTaxa = function( ) {
    if( !$scope.searchingStopped( ) ) { return false; }
    return $scope.taxa.length == 0;
  };
  $scope.noIdentifiers = function( ) {
    if( !$scope.searchingStopped( ) ) { return false; }
    return $scope.identifiers.length == 0;
  };
  $scope.noObservers = function( ) {
    if( !$scope.searchingStopped( ) ) { return false; }
    return $scope.observers.length == 0;
  };
  $scope.showPages = function( ) {
    if( !$scope.searchingStopped( ) ) { return false; }
    return $scope.pagination.total > $scope.pagination.perPage;
  };
  $scope.searchAndUpdateStats = function( options ) {
    if( $scope.searchDisabled ) { return true; }
    $scope.params.page = $scope.params.page || 1;
    $scope.pagingInitialized = false;
    $scope.pagination = $scope.pagination || { };
    $scope.pagination.page = $scope.params.page;
    $scope.pagination.section = 1;
    $scope.pagination.maxSections = 4;
    $scope.pagination.perSection = 24;
    $scope.pagination.perPage = $scope.pagination.maxSections * $scope.pagination.perSection;
    $scope.pagination.searching = true;
    $scope.pagination.stopped = false;
    // important to note we're not resetting scope.pagination.total to 0,
    // as that would cause ui.bootstrap to jump back to page 1
    $scope.numberTaxaShown = 15;
    $scope.numberIdentifiersShown = 15;
    $scope.numberObserversShown = 15;
    $scope.observersSort = "-observationCount";
    options = options || { };
    $scope.updateBrowserLocation( options );
    $scope.observations = [ ];
    $scope.taxa = [ ];
    $scope.identifiers = [ ];
    $scope.observers = [ ];
    $scope.resetStats( );
    var processedParams = ObservationsFactory.processParamsForAPI( _.extend( { },
      $scope.params, iNaturalist.localeParams( ) ),
      $scope.possibleFields);
    // recording there was some location in the search. That will be used
    // to hide the `Redo Search` button until the map moves
    if( processedParams.place_id || processedParams.swlat ) {
      $scope.hideRedoSearch = true;
    }
    var statsParams = _.omit( processedParams, [ "order_by", "order", "page" ] );
    var searchParams = _.extend( { }, processedParams, {
      page: $scope.apiPage( ),
      per_page: $scope.pagination.perSection });
    // prevent slow searches from overwriting current results
    var thisSearchTime = new Date( ).getTime( );
    $scope.lastSearchTime = thisSearchTime;
    ObservationsFactory.search( searchParams ).
                        then( function( response ) {
      if( $scope.lastSearchTime != thisSearchTime ) { return; }
      $scope.pagination.searching = false;
      thisSearchTime = new Date( ).getTime( );
      $scope.lastSearchTime = thisSearchTime;
      $scope.totalObservations = response.data.total_results;
      $scope.pagination.total = response.data.total_results;
      if( $scope.pagination.total === 0 ) {
        $scope.totalSpecies = 0;
        $scope.totalIdentifiers = 0;
        $scope.totalObservers = 0;
        $scope.pagination.stopped = true;
        return;
      }
      $scope.observations = ObservationsFactory.responseToInstances( response );
      ObservationsFactory.speciesCounts( statsParams ).then( function( response ) {
        if( $scope.lastSearchTime != thisSearchTime ) { return; }
        $scope.totalSpecies = response.data.total_results;
        $scope.taxa = _.map( response.data.results, function( r ) {
          var t = new iNatModels.Taxon( r.taxon );
          t.resultCount = r.count;
          return t;
        });
      });
      ObservationsFactory.identifiers( statsParams ).then( function( response ) {
        if( $scope.lastSearchTime != thisSearchTime ) { return; }
        $scope.totalIdentifiers = response.data.total_results;
        $scope.identifiers = _.map( response.data.results, function( r ) {
          var u = new iNatModels.User( r.user );
          u.resultCount = r.count;
          return u;
        });
      });
      ObservationsFactory.observers( statsParams ).then( function( response ) {
        if( $scope.lastSearchTime != thisSearchTime ) { return; }
        $scope.totalObservers = response.data.total_results;
        $scope.observers = _.map( response.data.results, function( r ) {
          var u = new iNatModels.User( r.user );
          u.observationCount = r.observation_count;
          u.speciesCount = r.species_count;
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
  $scope.apiPage = function( ) {
    return ( ( $scope.pagination.page - 1 ) * $scope.pagination.maxSections ) + $scope.pagination.section;
  };
  $scope.showMoreObservations = function( ) {
    $scope.pagination = $scope.pagination || { };
    if( !$scope.pagination.page ) { return; }
    if( !$scope.observations ) { return; }
    if( $scope.pagination.searching === true ) { return; }
    if( $scope.pagination.stopped === true ) { return; }
    $scope.pagination.section += 1;
    $scope.pagination.searching = true;
    var processedParams = ObservationsFactory.processParamsForAPI(
      _.extend( { }, $scope.params, iNaturalist.localeParams( ),
        { page: $scope.apiPage( ), per_page: $scope.pagination.perSection } ), $scope.possibleFields);
    ObservationsFactory.search( processedParams ).then( function( response ) {
      if( ( response.data.total_results <= ( response.data.page * response.data.per_page ) ) ||
          ( $scope.pagination.section >= $scope.pagination.maxSections ) ) {
        $scope.pagination.stopped = true;
      }
      $scope.observations = $scope.observations.concat(
        ObservationsFactory.responseToInstances( response ));
      $scope.pagination.searching = false;
    });
  };
  $scope.$watch( "pagination.page", function( ) {
    if( !$scope.pagingInitialized ) {
      $scope.pagingInitialized = true;
      return;
    }
    // if( !$scope.pagination ) { return; }
    $anchorScroll( );
    $scope.skipParamChange = true;
    $scope.params.page = $scope.pagination.page;
    $scope.updateBrowserLocation( );
    $scope.observations = [ ];
    $scope.pagination.section = 0;
    $scope.pagination.stopped = false;
    $scope.showMoreObservations( );
  });
  $scope.matchUrlState = function( ) {
    var urlParams = $location.search( );
    if( $scope.params.view && _.includes( $scope.possibleViews, $scope.params.view ) ) {
      $scope.currentView = urlParams.view;
    }
    if( $scope.possibleSubviews[ "observations" ] &&
        _.includes( $scope.possibleSubviews[ "observations" ], $scope.params.subview ) ) {
      $scope.currentSubview = $scope.params.subview;
    }
    if ( urlParams.on ) {
      $scope.params.dateType = 'exact';
    } else if ( urlParams.d1 || urlParams.d2 ) {
      $scope.params.dateType = 'range';
    } else if ( urlParams.month ) {
      $scope.params.dateType = 'month';
    }
    if ( urlParams.created_on ) {
      $scope.params.createdDateType = 'exact';
    } else if ( urlParams.created_d1 ) {
      $scope.params.createdDateType = 'range';
    }
    $scope.currentView = $scope.currentView || $scope.defaultView;
    $scope.currentSubview = $scope.currentSubview || $scope.defaultSubview;
    $scope.changeView( $scope.currentView, $scope.currentSubview, { skipSetLocation: true } );
    // once we set the views, the view params should be deleted
    delete $scope.params.view;
    delete $scope.params.subview;
    $scope.setObservationFields( );
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
    $scope.updatePlaceAutocomplete( );
  };
  $scope.filterByBounds = function( ) {
    $rootScope.$emit( "hideNearbyPlace" );
    $scope.removeSelectedPlace( );
    $rootScope.$emit( "updateParamsForCurrentBounds" );
  };
  $scope.removeSelectedPlace = function( ) {
    $scope.selectedPlace = null;
    $scope.hideRedoSearch = false;
    $scope.mapBounds = null;
    $scope.mapBoundsIcon = null;
  };
  $scope.removeSelectedBounds = function( ) {
    $scope.params.swlng = null;
    $scope.params.swlat = null;
    $scope.params.nelng = null;
    $scope.params.nelat = null;
    $scope.params.lat = null;
    $scope.params.lng = null;
    $scope.mapBounds = null;
    $scope.mapBoundsIcon = null;
    $scope.hideRedoSearch = false;
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
      // Sooo hacky, but hard to get it to translate the SELECT element before running the jquery ui code otherwise
      $( "#filters select[multiple]" ).not('.multiselectified').multiselect({
        minWidth: 150,
        checkAllText: I18n.t( "all" ),
        uncheckAllText: I18n.t( "none" ),
        open: function(event, ui) {
          $scope.params.dateType = 'month';
          $(event.target).parents('label:first').click();
        }
      });
      $( "#filters select[multiple]" ).not('.multiselectified').addClass('multiselectified');
    });
    // closing the filter box
    $( "body" ).on( "click", function( e ) {
      if( !$( "#filter-container" ).is( e.target ) &&
          $( "#filter-container" ).has( e.target ).length === 0 &&
          $( ".open" ).has( e.target ).length === 0 &&
          $( e.target ).parents('.ui-autocomplete').length === 0 &&
          $( e.target ).parents('.ui-datepicker').length === 0 &&
          $( e.target ).parents('.ui-datepicker-header').length === 0 &&
          $( e.target ).parents('.ui-multiselect-menu').length === 0 &&
          $( e.target ).parents('.observation-field').length === 0
        ) {
        $( "#filter-container" ).removeClass( "open" );
      };
    });
    // these buttons look better without a focus state
    $( ".btn.iconic-taxon" ).focus( function( ) {
      $( this ).blur( );
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
    // only search for "geocode" types, not businesses
    $scope.placeSearchBox = new google.maps.places.Autocomplete(
      document.getElementById( "place_name" ), {
        types: [ "geocode" ]
      });
    $scope.placeSearchBox.addListener( "place_changed", function( ) {
      var place = $scope.placeSearchBox.getPlace( );
      if( place && place.geometry ) { return $scope.setSearchedPlace( place ); }
      // there was no selected place, so query with the current input value
      $scope.searchPlaceAutocompleteService( );
    });
    $scope.placeAutocompleteService = new google.maps.places.AutocompleteService( );
  };
  $scope.searchPlaceAutocompleteService = function( ) {
    var q = $( "#place_name").val( );
    if( !q ) { return; }
    // query the autocomplete service for the text in the search input
    $scope.placeAutocompleteService.getQueryPredictions({ input: q },
      function( predictions, status ) {
        if( status != google.maps.places.PlacesServiceStatus.OK ||
            predictions.length == 0 || !predictions[ 0 ].place_id ) { return; }
        // now that we have the result, we need to query the PlacesService
        // for the geometry. That service needs to be associated with an
        // element, so use the map if we can, otherwise make one up
        var e = $scope.viewing( "observations", "map" ) ? $( "#map" ).data( "taxonMap" ) :
          document.createElement('div');
        var s = new google.maps.places.PlacesService( e );
        s.getDetails({ placeId: predictions[ 0 ].place_id }, function( place, status ) {
          if( status !== google.maps.places.PlacesServiceStatus.OK ) { return; }
          // use the details of the fetched place
          $scope.setSearchedPlace( place );
        });
      });
  };
  $scope.setSearchedPlace = function( place ) {
    if( !place || !place.geometry ) { return; }
    $scope.resetStats( );
    $scope.searchedPlace = place;
    $scope.focusOnSearchedPlace( );
    if( !$scope.viewing( "observations", "map" ) ) {
      $scope.mapNeedsAligning = true;
      $scope.delayedAlign = true;
    }
  };
  $scope.focusOnSearchedPlace = function( ) {
    if( $scope.searchedPlace ) {
      // setting a timer for automatching the searched place to a known place
      $scope.placeLastSearched = new Date( ).getTime( );
      $scope.autoPlaceSelect = true;
      $scope.mapBounds = null;
      var bounds;
      if( $scope.searchedPlace.geometry.viewport ) {
        bounds = $scope.searchedPlace.geometry.viewport;
      } else {
        var c = $scope.searchedPlace.geometry.location;
        // use some bounds which equate roughly to zoom level 15
        bounds = new google.maps.LatLngBounds(
            new google.maps.LatLng( c.lat( ) - 0.01, c.lng( ) - 0.02 ),
            new google.maps.LatLng( c.lat( ) + 0.01, c.lng( ) + 0.02 ));
      }
      // if the searched place is specific enough to have an address
      if( $scope.searchedPlace.adr_address &&
          $scope.searchedPlace.adr_address.match( /address/) ) {
        // add an X
        $scope.mapBoundsIcon = true;
        // align the map straight away w/o looking for a best place to choose
        $scope.mapBounds = bounds;
        $rootScope.$emit( "updateParamsForCurrentBounds" );
        $rootScope.$emit( "alignMap" );
      } else {
        // no X marker on the map
        $scope.mapBoundsIcon = null;
        var name = ( _.isObject( $scope.searchedPlace ) ?
          $scope.searchedPlace.name : $scope.searchedPlace ).toLowerCase( );
        var options = { bounds: bounds, params: { per_page: 1, name: name } };
        // search for a best nearby place with a similar name
        $rootScope.$emit( "searchForNearbyPlaces", options, function( response ) {
          if( !response || !response.data || !response.data.results ) {
            return $rootScope.$emit( "alignMap" );
          }
          if( response.data.results.standard.length > 0 ) {
            $scope.filterByPlace( response.data.results.standard[ 0 ] );
          } else if( response.data.results.community.length > 0 ) {
            $scope.filterByPlace( response.data.results.community[ 0 ] );
          } else {
            $scope.mapBounds = bounds;
            $rootScope.$emit( "updateParamsForCurrentBounds" );
            $rootScope.$emit( "alignMap" );
          }
        });
      }
    } else {
      // no searched place yet, so try searching with place input text
      $scope.searchPlaceAutocompleteService( );
    }
  };
  // when the place search input changes, delete the stored searched place
  $scope.$watch( "placeSearch", function( ) {
    $scope.searchedPlace = null;
  });
  $scope.setupTaxonAutocomplete = function( ) {
    $( "#filters input[name='taxon_name']" ).taxonAutocomplete({
      resetOnChange: false,
      bootstrapClear: true,
      search_external: false,
      id_el: $( "#filters input[name='taxon_id']" ),
      afterSelect: function( result ) {
        $scope.selectedTaxon = result.item;
        $scope.params.taxon_id = result.item.id;
        $scope.searchAndUpdateStats( );
      },
      afterUnselect: function( ) {
        if( $scope.params.taxon_id != null ) {
          $scope.selectedTaxon = null;
          $scope.params.taxon_id = null;
          $scope.searchAndUpdateStats( );
        }
      }
    });
  };
  $scope.updateTaxonAutocomplete = function( ) {
    if( $scope.selectedTaxon ) {
      $( "input[name='taxon_name']" ).trigger( "assignSelection", $scope.selectedTaxon );
    } else {
      $( "#filters input[name='taxon_name']" ).trigger( "search" );
    }
  };
  $scope.setupInatPlaceAutocomplete = function( ) {
    $( "input[name='inat_place_name']" ).placeAutocomplete({
      resetOnChange: false,
      bootstrapClear: true,
      id_el: $( "#filters input[name='place_id']" ),
      afterSelect: function( result ) {
        $scope.filterByPlace( result.item );
        if(!$scope.$$phase) { $scope.$digest( ); }
      },
      afterUnselect: function( ) {
        $scope.removeSelectedPlace( );
        if(!$scope.$$phase) { $scope.$digest( ); }
      }
    });
  };
  $scope.updatePlaceAutocomplete = function( ) {
    if( $scope.selectedPlace ) {
      $scope.selectedPlace.title = $scope.selectedPlace.display_name;
      $( "input[name='inat_place_name']" ).
        trigger( "assignSelection", $scope.selectedPlace );
    } else {
      $( "#filters input[name='inat_place_name']" ).trigger( "search" );
    }
  };
  $scope.setupUserAutocomplete = function( ) {
    $( "input[name='user_name']" ).userAutocomplete({
      resetOnChange: false,
      bootstrapClear: true,
      id_el: $( "#filters input[name='user_id']" ),
      afterSelect: function( result ) {
        $scope.params.user_id = result.item.login;
        if(!$scope.$$phase) { $scope.$digest( ); }
      },
      afterUnselect: function( ) {
        $scope.params.user_id = null;
        if(!$scope.$$phase) { $scope.$digest( ); }
      }
    });
    $scope.updateUserAutocomplete( );
  };
  $scope.updateUserAutocomplete = function( ) {
    if( $scope.params.user_id ) {
      $( "input[name='user_name']" ).
        trigger( "assignSelection",
          { id: $scope.params.user_id, title: $scope.params.user_id } );
    } else {
      $( "#filters input[name='user_name']" ).trigger( "search" );
    }
  };
  $scope.setupProjectAutocomplete = function( ) {
    $( "input[name='project_name']" ).projectAutocomplete({
      resetOnChange: false,
      bootstrapClear: true,
      id_el: $( "#filters input[name='project_id']" ),
      afterSelect: function( result ) {
        $scope.params.project_id = result.item.slug;
        if(!$scope.$$phase) { $scope.$digest( ); }
      },
      afterUnselect: function( ) {
        $scope.params.project_id = null;
        if(!$scope.$$phase) { $scope.$digest( ); }
      }
    });
    $scope.updateProjectAutocomplete( );
  };
  $scope.updateProjectAutocomplete = function( ) {
    if( $scope.params.project_id ) {
      $( "input[name='project_name']" ).
        trigger( "assignSelection",
          { id: $scope.params.project_id, title: $scope.params.project_id } );
    } else {
      $( "#filters input[name='project_name']" ).trigger( "search" );
    }
  };
  $scope.setupBrowserStateBehavior = function( ) {
    window.onpopstate = function( event ) {
      var state = _.extend( { }, event.state || $scope.initialBrowserState );
      var previousParams = _.extend( { }, $scope.defaultParams, state.params );
      // needed to serialize some objects for storing in browser state
      // so now turn them back into object instances for comparison
      if( state.selectedTaxon ) {
        state.selectedTaxon = new iNatModels.Taxon( JSON.parse( state.selectedTaxon ) );
      }
      if( state.selectedPlace ) {
        state.selectedPlace = new iNatModels.Place( JSON.parse( state.selectedPlace ) );
      }
      // we could set place and taxon below, and that should not run searches
      $scope.searchDisabled = true;
      $scope.mapBoundsIcon = state.mapBoundsIcon;
      // resture the bounds we had to store as JSON
      if( state.selectedPlace != $scope.selectedPlace ) {
        $scope.filterByPlace( state.selectedPlace );
      }
      if( state.mapBounds ) {
        $scope.mapBounds = new google.maps.LatLngBounds(
          new google.maps.LatLng( state.mapBounds.south, state.mapBounds.west ),
          new google.maps.LatLng( state.mapBounds.north, state.mapBounds.east ));
      } else { $scope.mapBounds = null };
      if( state.selectedTaxon != $scope.selectedTaxon ) {
        $scope.selectedTaxon = state.selectedTaxon;
        $scope.updateTaxonAutocomplete( );
      } else if( state.params && state.params.taxon_id != $scope.params.taxon_id ) {
        // useful for selecting a taxon from the observations grid view
        $scope.params.taxon_id = state.params.taxon_id;
        $scope.initializeTaxonParams( );
      }
      var previousProcessedParams = ObservationsFactory.processParamsForAPI( previousParams, $scope.possibleFields );
      delete previousProcessedParams.view;
      delete previousProcessedParams.subview;
      // restoring state of iconic taxa filters, (e.g { Chromista: true })
      if( previousParams.iconic_taxa ) {
        previousParams._iconic_taxa = _.object( _.map( previousParams.iconic_taxa.split(","),
          function( n ) { return [ n, true ]; }
        ));
      }
      $scope.searchDisabled = false;
      if( !_.isEqual( $scope.processedParams, previousProcessedParams ) ) {
        $scope.goingBack = true;
        $scope.alignMapOnSearch = true;
        $scope.delayedAlign = true;
        $scope.params = previousParams;
      }
      // make sure we don't set the location again when going back in history
      $scope.changeView( previousParams.view || $scope.defaultView,
        previousParams.subview || $scope.defaultSubview, { skipSetLocation: true } );
      $scope.setObservationFields( );
      if(!$scope.$$phase) { $scope.$digest( ); }
    };
  };
  $scope.determineFieldNames = function( ) {
    _.map( $( "#filters input,select" ), function( input ) {
      var name = $( input ).attr( "ng-model" ) || input.name;
      name = name.replace( "params.", "" );
      $scope.possibleFields.push( name );
    });
    $scope.defaultProcessedParams = ObservationsFactory.processParamsForAPI( $scope.defaultParams, $scope.possibleFields );
  };
  $scope.paramsForUrl = function( ) {
    var urlParams = _.extend( { }, $scope.params );
    if( urlParams.month && !_.isArray( urlParams.month ) ) {
      urlParams.month = urlParams.month.split(",");
    }
    urlParams.iconic_taxa = _.keys( urlParams._iconic_taxa );
    if( urlParams.project_id ) {
      urlParams.projects = urlParams.project_id;
    }
    delete urlParams._iconic_taxa;
    delete urlParams.project_id;
    delete urlParams.order;
    delete urlParams.order_by;
    delete urlParams.dateType;
    delete urlParams.createdDateType;
    delete urlParams.view;
    delete urlParams.subview;
    delete urlParams.viewer_id;
    return $.param( urlParams );
  };
  $scope.showInfowindow = function( o ) {
    $rootScope.$emit( "showInfowindow", o );
  };
  $scope.hideInfowindow = function( ) {
    $rootScope.$emit( "hideInfowindow" );
  };
  $scope.toggleShowViewerObservations = function( ) {
    if ( !CURRENT_USER ) { return; };
    if ( $scope.params.user_id == CURRENT_USER.id || $scope.params.user_id == CURRENT_USER.login ) {
      $scope.params.user_id = null;
    } else {
      $scope.params.user_id = CURRENT_USER.login;
    }
  };
  $scope.canShowObservationFields = function( ) {
    return ($scope.params.observationFields && _.size( $scope.params.observationFields ) > 0);
  }
  $scope.setObservationFields = function( ) {
    var urlParams = $location.search( );
    // Put the URL params that correspond to observation fields in their own part of the scope
    // If there's a more readable way to perform this simple task, please let me know.
    $scope.params.observationFields = _.reduce( urlParams, function( memo, v, k ) {
      if( k.match(/(\w+):(\w+)/ ) ) {
        // true represents a key with no value, so leave value undefined
        k = decodeURIComponent(k).replace( /(%20|\+)/g, " ");
        if( _.isString( v ) ) { v = v.replace( /(%20|\+)/g, " "); }
        memo[k] = ( v === true ) ? undefined : v;
      }
      return memo;
    }, { } );
  }
  $scope.removeObservationField = function( field ) {
    if( !$scope.params.observationFields ) {
      return;
    }
    if ( !$scope.params.observationFields.hasOwnProperty( field ) ) {
      return;
    }
    delete $scope.params.observationFields[ field ];
    return false;
  };

  $scope.preInitialize( );
}]);


application.controller( "MapController", [ "ObservationsFactory", "PlacesFactory", "shared", "$scope", "$rootScope",
function( ObservationsFactory, PlacesFactory, shared, $scope, $rootScope ) {
  $scope.placeLayerStyle = {
    strokeColor: "#d77a3b",
    strokeOpacity: 0.75,
    strokeWeight: 5,
    fillOpacity: 0
  };
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
    var defaultMapType = PREFERRED_MAP_TYPE || google.maps.MapTypeId.LIGHT;
    $( "#map" ).taxonMap({
      urlCoords: true,
      mapType: defaultMapType,
      showAllLayer: false,
      disableFullscreen: true,
      mapTypeControl: false,
      overlayMenu: false,
      zoomControl: false,
      infoWindowCallback: $scope.infoWindowCallback,
      minZoom: 2
    });
    $scope.map = $( "#map" ).data( "taxonMap" );
    $scope.map.mapTypes.set(iNaturalist.Map.MapTypes.LIGHT_NO_LABELS, iNaturalist.Map.MapTypes.light_no_labels);
    $scope.map.mapTypes.set(iNaturalist.Map.MapTypes.LIGHT, iNaturalist.Map.MapTypes.light);
    // preparing the mapType, Labels, and Terrain buttons initial state
    // which can change depending on the user session/preferences
    if( defaultMapType == google.maps.MapTypeId.SATELLITE ||
        defaultMapType == google.maps.MapTypeId.HYBRID ) {
      $scope.$parent.mapType = "satellite";
    }
    if( defaultMapType == iNaturalist.Map.MapTypes.LIGHT_NO_LABELS ||
        defaultMapType == google.maps.MapTypeId.SATELLITE ) {
      $scope.$parent.mapLabels = false;
    }
    if( defaultMapType == google.maps.MapTypeId.TERRAIN ) {
      $scope.$parent.mapTerrain = true;
    }
    // waiting a bit after creating the map to initialize the layers
    // to avoid issues with map aligning, letting the browser catch up
    setTimeout( function( ) {
      if( !$scope.mapLayersInitialized ) {
        $scope.setMapLayers( true );
        // more delays before enabling onMoves so setMapLayers
        // can finish aligning the map if it needs to
        setTimeout( function( ) {
          $scope.map.addListener( "dragend", function( ) { $scope.delayedOnMove( ); });
          $scope.map.addListener( "zoom_changed", function( ) { $scope.delayedOnMove( ); });
        }, 500 );
        iNaturalist.Legend($('#map-legend-container').get(0), $scope.map, {hideFeatured: true});
      }
    }, 300);
  }
  $scope.updateParamsForCurrentBounds = function( ) {
    var bounds = $scope.$parent.mapBounds;
    if( !bounds && $scope.$parent.viewing( "observations", "map" ) && $scope.map ) {
      bounds = $scope.map.getBounds( );
    }
    if( !bounds ) { return; }
    // just making sure we have real bounds
    $scope.$parent.mapBounds = bounds;
    var ne     = bounds.getNorthEast( ),
        sw     = bounds.getSouthWest( );
    $scope.$parent.params.swlng = sw.lng( );
    $scope.$parent.params.swlat = sw.lat( );
    $scope.$parent.params.nelng = ne.lng( );
    $scope.$parent.params.nelat = ne.lat( );
    $scope.$parent.selectedPlace = null;
  };
  $rootScope.$on( "searchForNearbyPlaces", function( event, options, callback ) {
    $scope.searchForNearbyPlaces( options, callback );
  });
  $scope.searchForNearbyPlaces = function( options, callback ) {
    $scope.$parent.searchingNearbyPlaces = true;
    var onMap = $scope.viewing("observations", "map");
    if( $scope.$parent.placeSearchBox && $scope.map && onMap ) {
      $scope.$parent.placeSearchBox.setBounds( $scope.map.getBounds( ) );
    }
    options = options || { };
    options.params = options.params || { };
    if( onMap ) {
      options.bounds = options.bounds || $scope.map.getBounds( );
    } else if( $scope.mapBounds ) {
      options.bounds = options.bounds || $scope.mapBounds;
    }
    if( options.bounds ) {
      options.params.swlat = options.bounds.getSouthWest( ).lat( );
      options.params.swlng = options.bounds.getSouthWest( ).lng( );
      options.params.nelat = options.bounds.getNorthEast( ).lat( );
      options.params.nelng = options.bounds.getNorthEast( ).lng( );
    }
    // search a little left of center
    shared.offsetCenter({ map: (onMap ? $scope.map : null), left: -130, up: 0 }, function( center ) {
      if( center ) {
        options.params.lat = center.lat( );
        options.params.lng = center.lng( );
      }
      callback = callback || $scope.nearbyPlaceCallback;
      PlacesFactory.nearby( options.params ).then( callback );
    });
  };
  $scope.nearbyPlaceCallback = function( response ) {
    if( !( response && response.data && response.data.results ) ) { return { }; }
    var nearbyPlaces = [ ];
    if( response.data.total_results ) {
      nearbyPlaces = {
        standard: _.map( response.data.results.standard, function( r ) {
          return new iNatModels.Place( r );
        }),
        community: _.map( response.data.results.community, function( r ) {
          return new iNatModels.Place( r );
        })
      };
    }
    $scope.$parent.nearbyPlaces = nearbyPlaces;
    $scope.$parent.searchingNearbyPlaces = false;
    $scope.lastMoveTime = null;
  };
  $rootScope.$on( "showNearbyPlace", function( event, place ) {
    if( $scope.nearbyPlaceLayer ) { $scope.nearbyPlaceLayer.setMap( null ); }
    $scope.nearbyPlaceLayer = null;
    $scope.nearbyPlaceLayer = new google.maps.Data({ style:
      _.extend( { }, $scope.placeLayerStyle, {
        strokeOpacity: 0.6,
        strokeWeight: 4
      })
    });
    var geojson = { type: "Feature", geometry: place.geometry_geojson };
    $scope.nearbyPlaceLayer.addGeoJson( geojson );
    $scope.nearbyPlaceLayer.setMap( $scope.map );
  });
  $rootScope.$on( "hideNearbyPlace", function( ) {
    if( $scope.nearbyPlaceLayer ) { $scope.nearbyPlaceLayer.setMap( null ); }
    $scope.nearbyPlaceLayer = null;
  });
  $rootScope.$on( "setMapLayers", function( event, align ) {
    $scope.setMapLayers( align );
  });
  $rootScope.$on( "alignMap", function( ) {
    $scope.alignMap( );
  });
  $rootScope.$on( "setMapType", function( event, mapType, mapLabels, mapTerrain ) {
    if ( !$scope.map ) { return; };
    var mapTypeId;
    if (mapType == 'map') {
      if (mapTerrain) {
        mapTypeId = google.maps.MapTypeId.TERRAIN;
      } else {
        mapTypeId = mapLabels ? iNaturalist.Map.MapTypes.LIGHT : iNaturalist.Map.MapTypes.LIGHT_NO_LABELS;
      }
    } else {
      mapTypeId = mapLabels ? google.maps.MapTypeId.HYBRID : google.maps.MapTypeId.SATELLITE;
    }
    $scope.map.setMapTypeId(mapTypeId);
    updateSession({ prefers_observations_search_map_type: mapTypeId });
  });
  $scope.lastMoveTime = 0;
  $scope.delayedOnMove = function( ) {
    // show the `Redo Search` button when the map moves
    if( !$scope.$parent.searchingNearbyPlaces ) {
      $scope.$parent.searchingNearbyPlaces = true;
      if(!$scope.$parent.$$phase) { $scope.$parent.$digest( ); }
    }
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
    }
    if( $scope.$parent.hideRedoSearch ) {
      $scope.$parent.hideRedoSearch = false;
      if(!$scope.$parent.$$phase) { $scope.$parent.$digest( ); }
    }
  };
  $scope.alignMap = function( ) {
    // don't attempt aligning if we're not viewing the map
    if( $scope.mapLayersInitialized && $scope.$parent.viewing( "observations", "map" ) ) {
      if( $scope.$parent.mapBounds ) {
        $scope.map.fitBounds( $scope.$parent.mapBounds );
        $rootScope.$emit( "offsetCenter", 130, 0 );
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
        if( $scope.$parent.searchedPlace ) {
          $scope.$parent.searchedPlace.geometry.viewport = bounds;
        }
        $scope.$parent.mapBounds = bounds;
      }
      $scope.$parent.mapNeedsAligning = false;
    }
    $rootScope.$emit( "searchForNearbyPlaces" );
  };
  $rootScope.$on( "showInfowindow", function( event, o ) {
    if( $scope.snippetInfoWindowObservation &&
      $scope.snippetInfoWindowObservation.id == o.id ) { return; }
    if( $scope.snippetInfoWindow ) {
      $scope.snippetInfoWindow.close( );
    }
    $scope.snippetInfoWindowObservation = o;
    $scope.snippetInfoWindow = $scope.snippetInfoWindow ||
      $scope.map.getInfoWindow({ disableAutoPan: true });
    var ll = o.location.split(",");
    var latLng = new google.maps.LatLng( ll[0], ll[1] );
    $scope.infoWindowCallback( $scope.map, iw, latLng, o.id );
  });
  $rootScope.$on( "hideInfowindow", function( event, o ) {
    $scope.snippetInfoWindowObservation = null;
    if( $scope.snippetInfoWindow ) {
      $scope.snippetInfoWindow.close( );
    }
  });
  $scope.infoWindowCallbackStartTime;
  // callback method when an observation is clicked on the map
  // fetch the observation details, and render the snippet template
  $scope.infoWindowCallback = function( map, iw, latLng, observation_id, options ) {
    map.infoWindowSetContent( iw, latLng, "<div class='infowindow loading'>" +
      I18n.t( "loading" ) + "</div>", options );
    var time = new Date( ).getTime( );
    $scope.infoWindowCallbackStartTime =  time;
    ObservationsFactory.show( observation_id, iNaturalist.localeParams( ) ).then( function( response ) {
      observations = ObservationsFactory.responseToInstances( response );
      if( observations.length > 0 ) {
        $scope.infoWindowObservation = observations[ 0 ];
        // make sure the view is updated
        if(!$scope.$parent.$$phase) { $scope.$parent.$digest( ); }
        // delay this a bit so the view has time to update
        setTimeout(function( ) {
          if( $scope.infoWindowCallbackStartTime !== time ) { return; }
          map.infoWindowSetContent( iw, latLng, $( "#infoWindowSnippet" ).html( ), options );
        }, 10)
      }
    });
  };
  $scope.setMapLayers = function( align ) {
    if( !$scope.map ) { return };
    if( !$scope.$parent.parametersInitialized ) { return };
    window.inatTaxonMap.removeObservationLayers( $scope.map, { title: "Observations" } );
    var layerParams = ObservationsFactory.processParamsForAPI( $scope.params, $scope.possibleFields );
    if( _.isEqual( $scope.$parent.defaultProcessedParams, layerParams ) ) {
      layerParams.ttl = 86400;
    }
    window.inatTaxonMap.addObservationLayers( $scope.map, {
      title: "Observations",
      mapStyle: "colored_heatmap",
      observationLayers: [ layerParams ],
      infoWindowCallback: $scope.infoWindowCallback
    });
    // fully remove any existing data layer
    if( $scope.selectedPlaceLayer ) { $scope.selectedPlaceLayer.setMap( null ); }
    if( $scope.boundingBoxCenterIcon ) { $scope.boundingBoxCenterIcon.setMap( null ); }
    $scope.selectedPlaceLayer = null;
    $scope.boundingBoxCenterIcon = null;
    var xMarkerPosition;
    $scope.selectedPlaceLayer = new google.maps.Data({ style: $scope.placeLayerStyle });
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
      // google.maps.Rectangle seems more reliable than using GeoJSON here
      $scope.selectedPlaceLayer = new google.maps.Rectangle(
        _.extend( { }, $scope.placeLayerStyle, {
          map: $scope.map,
          bounds: {
            north: parseFloat( $scope.params.nelat ),
            south: parseFloat( $scope.params.swlat ),
            east: parseFloat( $scope.params.nelng ),
            west: parseFloat( $scope.params.swlng )
          }
        })
      );
      // add an X marker in the center of the bounding box
      if( $scope.$parent.mapBoundsIcon && $scope.searchedPlace ) {
        xMarkerPosition = $scope.searchedPlace.geometry.location;
      }
    } else if( $scope.params.lat && $scope.params.lng ) {
      xMarkerPosition = {
        lat: parseFloat( $scope.params.lat ),
        lng: parseFloat( $scope.params.lng )
      };
      $scope.selectedPlaceLayer = new google.maps.Circle(
        _.extend( { }, $scope.placeLayerStyle, {
          map: $scope.map,
          radius: 10000,
          center: xMarkerPosition
        })
      );
    }
    if( xMarkerPosition ) {
      $scope.boundingBoxCenterIcon = new google.maps.Marker({
        position: xMarkerPosition,
        icon: {
          url: "/mapMarkers/x.svg",
          scaledSize: new google.maps.Size( 20, 20 ),
          anchor: new google.maps.Point( 10, 10 ),
        },
        map: $scope.map
      });
    }
    $scope.mapLayersInitialized = true;
    if( align ) {
      var timeout = $scope.$parent.delayedAlign ? 20 : 1;
      setTimeout( function( ) {
        $scope.alignMap( );
      }, timeout );
    }
    $scope.$parent.delayedAlign = false;
  };
  $scope.zoomIn = function( ) {
    $scope.map.setZoom( $scope.map.getZoom() + 1 );
  };
  $scope.zoomOut = function( ) {
    $scope.map.setZoom( $scope.map.getZoom() - 1 );
  };
  $scope.findUserLocation = function( ) {
    if( typeof( navigator.geolocation ) != "undefined" ) {
      var getCurrentPositionSuccess = function( location ) {
        $scope.findingUserLocation = false;
        var pos = { 
          lat: location.coords.latitude, 
          lng: location.coords.longitude
        };
        var circle = new google.maps.Circle({
          center: pos,
          radius: (location.accuracy*10) || 1000
        });
        $scope.map.fitBounds( circle.getBounds( ) );
      };
      var getCurrentPositionFailure = function( ) {
        alert( I18n.t('failed_to_find_your_location') );
        $scope.findingUserLocation = false;
      };
      $scope.findingUserLocation = true;
      navigator.geolocation.getCurrentPosition(getCurrentPositionSuccess, getCurrentPositionFailure);
    }
  };
  $scope.togglFullscreen = function( ) {
    $scope.fullscreen = !$scope.fullscreen;
  };
}]);
