var application = angular.module( "ObservationSearch", [
  "google.places",
  "infinite-scroll",
  "ngRoute",
  "templates",
  "iNatAPI"
]);

// disable scrolling to the top when we're updating the view
application.value( "$anchorScroll", angular.noop );

// defining the views
application.directive( "resultsMap", function( ) {
  return {
    templateUrl: "ang/templates/observation_search/results_map.html",
    link: function( scope, element, attr ) {
      scope.setupMap( );
      // the observation div on the map is a scrollable div in a scrollable page
      // make sure that when you scroll to the botton of that div, the page
      // doesn't start scrolling down
      $( "#obs" ).isolatedScroll( );
    }
  };
});
application.directive( "resultsGrid", function( ) {
  return {
    templateUrl: "ang/templates/observation_search/results_grid.html"
  };
});
application.directive( "resultsTable", function( ) {
  return {
    templateUrl: "ang/templates/observation_search/results_table.html"
  };
});
application.directive( "filterMenu", function( ) {
  return {
    templateUrl: "ang/templates/observation_search/filter_menu.html",
    link: function( scope, element, attr ) {
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
            $( ".open" ).has( e.target ).length === 0 ) {
          $( "#filter-container" ).removeClass( "open" );
        };
      });
    }
  };
});

application.controller( "SearchController", [ "ObservationsFactory", "shared", "$scope", "$rootScope", "$location",
function( ObservationsFactory, shared, $scope, $rootScope, $location ) {
  $scope.possibleViews = [ "map", "grid", "table" ];
  $scope.defaultView = "map";
  $scope.defaultParams = {
    has_photos: true,
    taxon_id: null,
    order_by: "observations.id",
    order: "desc",
    dateType: "any",
    geoType: "world"
  };
  $scope.resetStats = function( ) {
    $rootScope.totalObservations = "--";
    $rootScope.totalSpecies = "--";
    $rootScope.totalObservers = "--";
    $rootScope.totalIdentifiers = "--";
  };
  $scope.resetParams = function( ) {
    $scope.params = _.clone( $scope.defaultParams );
  };
  $scope.setInitialParams = function( ) {
    $scope.params = _.extend( { }, $scope.defaultParams, urlParams );
  };
  $scope.updateBrowserLocation = function( ) {
    var newParams = [ ];
    _.each( $scope.params, function( value, param ) {
      if( $scope.defaultParams.hasOwnProperty( param ) && value === $scope.defaultParams[ param ] ) {
        return;
      }
      newParams.push( [ param, value ] );
    });
    if( $scope.currentView != $scope.defaultView ) {
      newParams.push( [ "view", $scope.currentView ] );
    }
    newParams = _.sortBy( newParams, function( arr ) {
      return arr[ 0 ];
    });
    $location.search( _.object( newParams ) );
  };
  $scope.changeView = function( newView ) {
    if( newView && newView != $scope.currentView ) {
      $scope.currentView = newView;
      if( $scope.observations && $scope.observations ) {
        $scope.observations = $scope.observations.slice( 0, 10 );
      }
      if( newView == "map" ) {
        setTimeout( function( ) {
          google.maps.event.trigger(window.map, 'resize');
        }, 200);
      }
      $scope.updateBrowserLocation( );
    }
  };
  $scope.setGeoFilter = function( filter ) {
    if( filter == "visible" ) {
      $scope.params.geoType = "map";
      $rootScope.$emit( "updateParamsForCurrentBounds" );
    } else {
      $scope.params.swlng = null;
      $scope.params.swlat = null;
      $scope.params.nelng = null;
      $scope.params.nelat = null;
      $scope.params.geoType = "world";
    }
  };
  $scope.searchAndUpdateStats = function( ) {
    var processedParams = shared.processParams( _.clone( $scope.params ) );
    $scope.updateBrowserLocation( );
    ObservationsFactory.search( processedParams ).then( function( response ) {
      $scope.page = 1;
      $scope.resetStats( );
      $rootScope.totalObservations = response.data.total_results;
      $scope.observations = ObservationsFactory.responseToInstances( response );
      ObservationsFactory.stats( processedParams ).then( function( response ) {
        $rootScope.totalObservers = response.data.observer_count;
        $rootScope.totalIdentifiers = response.data.identifier_count;
      });
      ObservationsFactory.speciesCounts( processedParams ).then( function( response ) {
        $rootScope.totalSpecies = response.data.leaf_count;
      });
    });
  };
  $scope.nextPage = function( ) {
    if( !$scope.page ) { return; }
    if( $scope.busy === true ) { return; }
    $scope.page += 1;
    $scope.busy = true;
    var processedParams = shared.processParams(
      _.extend( { }, $scope.params, { page: $scope.page } ));
    ObservationsFactory.search( processedParams ).then( function( response ) {
      $scope.observations = $scope.observations.concat(
        ObservationsFactory.responseToInstances( response ));
      $scope.busy = false;
    });
  };
  var urlParams = $location.search( );
  if( _.contains( $scope.possibleViews, urlParams.view ) ) {
    $scope.currentView = urlParams.view;
  }
  $scope.currentView = $scope.currentView || $scope.defaultView;
  $scope.shared = shared;
  $scope.resetStats( );
  $scope.setInitialParams( );

  // reload observations whenever params change
  // without deepObjectComparison the params hash will always
  // appear the same when its values change
  var deepObjectComparison = true;
  $scope.$watch( "params", function( ) {
    $scope.searchAndUpdateStats( );
  }, deepObjectComparison );

  $scope.$watch( "place", function( ) {
    if( $scope.place && $scope.place.geometry ) {
      $rootScope.$emit( "updateMapForPlace", $scope.place );
    }
  });

  angular.element( document ).ready( function( ) {
    $( "#filters input[name='taxon_name']" ).taxonAutocomplete({
      taxon_id_el: $( "#filters input[name='taxon_id']" ),
      afterSelect: function( result ) {
        $scope.params.taxon_id = result.item.id;
        $scope.searchAndUpdateStats( );
      },
      afterUnselect: function( ) {
        $scope.params.taxon_id = null;
        $scope.searchAndUpdateStats( );
      }
    });
  });
}]);


application.controller( "MapController", [ "shared", "$scope", "$rootScope", "$anchorScroll",
function( shared, $scope, $rootScope, $anchorScroll ) {
  $rootScope.$on( "updateParamsForCurrentBounds", function( event, force ) {
    $scope.updateParamsForCurrentBounds( force );
  });
  $scope.updateParamsForCurrentBounds = function( force ) {
    if( !( $scope.$parent.params.geoType == "map" || force === true )) { return; }
    var bounds = $scope.map.getBounds( ),
        ne     = bounds.getNorthEast( ),
        sw     = bounds.getSouthWest( );
    $scope.$parent.params.swlng = sw.lng( );
    $scope.$parent.params.swlat = sw.lat( );
    $scope.$parent.params.nelng = ne.lng( );
    $scope.$parent.params.nelat = ne.lat( );
    if(!$scope.$parent.$$phase) {
      $scope.$parent.$digest( );
    }
  };
  $rootScope.$on( "updateMapForPlace", function( event, place ) {
    if( place && $scope.map ) {
      if( place.geometry.viewport ) {
        $scope.map.fitBounds( place.geometry.viewport );
      } else {
        $scope.map.setCenter( place.geometry.location );
        $scope.map.setZoom( 15 );
      }
      $scope.updateParamsForCurrentBounds( true );
    }
  });
  $scope.refreshRequestTime = 0;
  $scope.delayedUpdateParamsForCurrentBounds = function( ) {
    var thisRequestTime = new Date( ).getTime( );
    refreshRequestTime = thisRequestTime;
    setTimeout( function( ) {
      if( refreshRequestTime == thisRequestTime ) {
        $scope.updateParamsForCurrentBounds( );
      }
    }, 800 );
  };
  $scope.setupMap = function( ) {
    $( "#map" ).taxonMap({
      urlCoords: true,
      mapType: google.maps.MapTypeId.TERRAIN,
      showLegend: true,
      showAllLayer: false,
      longitude: 130
    });
    $scope.map = $( "#map" ).data( "taxonMap" );
    if( $scope.$parent.params.nelat || $scope.$parent.params.nelng ||
        $scope.$parent.params.swlat || $scope.$parent.params.swlng ) {
      var bounds = new google.maps.LatLngBounds(
        new google.maps.LatLng( $scope.$parent.params.swlat, $scope.$parent.params.swlng ),
        new google.maps.LatLng( $scope.$parent.params.nelat, $scope.$parent.params.nelng ) );
      $scope.map.fitBounds( bounds );
      // adjust for the fact that fitBounds zooming out a little
      $scope.map.setZoom( $scope.map.getZoom( ) + 1);
    }
    $scope.map.addListener( "dragend", $scope.delayedUpdateParamsForCurrentBounds );
    $scope.map.addListener( "zoom_changed", $scope.delayedUpdateParamsForCurrentBounds );
    $scope.setMapLayers( );
  };
  $scope.$watch( "params", function( ) {
    $scope.setMapLayers( );
  }, true );
  $scope.setMapLayers = function( ) {
    window.inatTaxonMap.removeObservationLayers( $scope.map, { title: "Observations" } );
    window.inatTaxonMap.addObservationLayers( $scope.map, {
      title: "Observations",
      mapStyle: "summary",
      observationLayers: [
        shared.processParams( _.clone( $scope.params ) )
      ]
    });
  };
}]);

application.controller( "TableController", [ function( ) {

}]);

application.controller( "GridController", [ "$scope", function( $scope ) {

}]);
