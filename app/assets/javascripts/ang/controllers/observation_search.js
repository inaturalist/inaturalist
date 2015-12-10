var application = angular.module( "ObservationSearch", [
  "google.places",
  "infinite-scroll",
  "ngRoute",
  "templates",
  "ehFilters", // angular-capitalize
  "iNatAPI",
  "ui.bootstrap",
  "angularMoment"
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

// disable scrolling to the top when we're updating the view
application.value( "$anchorScroll", angular.noop );

application.controller( "SearchController", [ "ObservationsFactory", "PlacesFactory",
"TaxaFactory", "shared", "$scope", "$rootScope", "$location",
function( ObservationsFactory, PlacesFactory, TaxaFactory, shared, $scope, $rootScope, $location ) {
  $scope.possibleViews = [ "observations", "species", "identifiers", "observers" ];
  $scope.possibleSubviews = { observations: [ "map", "grid", "table" ] };
  $scope.defaultView = "observations";
  $scope.defaultSubview = "map";
  $scope.defaultParams = {
    has_photos: true,
    taxon_id: null,
    order_by: "observations.id",
    order: "desc",
    dateType: "any",
    geoType: "world"
  };
  $scope.nearbyPlaces = [ ];
  $scope.setupFilters = function() {
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
    $('#filters select[multiple]').multiselect({
      minWidth: 150,
      checkAllText: I18n.t('all'),
      uncheckAllText: I18n.t('none')
    })
  }
  $scope.resetStats = function( ) {
    $scope.totalObservations = "--";
    $scope.totalSpecies = "--";
    $scope.totalObservers = "--";
    $scope.totalIdentifiers = "--";
    $scope.taxa = [ ];
    $scope.identifiers = [ ];
    $scope.observers = [ ];
  };
  $scope.resetParams = function( ) {
    $scope.params = _.clone( $scope.defaultParams );
  };
  $scope.setInitialParams = function( ) {
    $scope.params = _.extend( { }, $scope.defaultParams, urlParams );
    // load taxon auto name and photo for autocomplete
    if( $scope.params.taxon_id ) {
      TaxaFactory.show( $scope.params.taxon_id ).then( function( response ) {
        taxa = TaxaFactory.responseToInstances( response );
        if( taxa.length > 0 ) {
          var taxon = taxa[ 0 ];
          if( taxon.square_photo_url ) {
            $( "#filters .ac-select-thumb img" ).attr( "src", taxon.square_photo_url );
          }
          $( "input[name='taxon_name']" ).attr( "value", taxon.preferredNameInLocale( "en" ) );
        }
      });
    }
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
    if( $scope.currentSubview != $scope.defaultSubview ) {
      newParams.push( [ "subview", $scope.currentSubview ] );
    }
    newParams = _.sortBy( newParams, function( arr ) {
      return arr[ 0 ];
    });
    $location.search( _.object( newParams ) );
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
  $scope.changeView = function( newView, newSubview ) {
    if( newView != $scope.currentView || newSubview != $scope.currentSubview ) {
      $scope.currentView = newView;
      $scope.currentSubview = newSubview;
      if( $scope.observations && $scope.observations ) {
        $scope.observations = $scope.observations.slice( 0, 40 );
      }
      if( $scope.currentSubview == "map" ) {
        setTimeout( function( ) {
          google.maps.event.trigger( window.map, "resize" );
        }, 200);
      }
      $scope.updateBrowserLocation( );
    }
  };
  $scope.setGeoFilter = function( filter ) {
    if( filter == "visible" ) {
      $scope.params.geoType = "map";
      $rootScope.$emit( "hideNearbyPlace" );
      $scope.currentPlace = null;
      $rootScope.$emit( "updateParamsForCurrentBounds" );
    } else {
      $scope.params.geoType = "world";
      $rootScope.$emit( "hideNearbyPlace" );
      $scope.params.place_id = null;
      $scope.currentPlace = null;
      $scope.params.swlng = null;
      $scope.params.swlat = null;
      $scope.params.nelng = null;
      $scope.params.nelat = null;
    }
  };
  $scope.searchAndUpdateStats = function( ) {
    $scope.page = 1;
    var processedParams = shared.processParams(
      _.extend( { }, $scope.params, { page: $scope.page } ));
    $scope.updateBrowserLocation( );
    ObservationsFactory.search( processedParams ).then( function( response ) {
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
  if( urlParams.view && _.contains( $scope.possibleViews, urlParams.view ) ) {
    $scope.currentView = urlParams.view;
  }
  if( $scope.currentView && $scope.possibleSubviews[ $scope.currentView ] &&
      _.contains( $scope.possibleSubviews[ $scope.currentView ], urlParams.subview ) ) {
    $scope.currentSubview = urlParams.subview;
  }
  $scope.changeView( urlParams.view, urlParams.subview );
  $scope.currentView = $scope.currentView || $scope.defaultView;
  $scope.currentSubview = $scope.currentSubview || $scope.defaultSubview;
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
      // setting a timer for automatching the searched place to a known place
      $scope.placeLastSearched = new Date( ).getTime( );
      $scope.shouldMatchPlaceSearch = true;
      $rootScope.$emit( "updateMapForPlace", $scope.place );
    }
  });
  $scope.showNearbyPlace = function( place ) {
    $rootScope.$emit( "showNearbyPlace", place );
  };
  $scope.hideNearbyPlace = function( place ) {
    $rootScope.$emit( "hideNearbyPlace", place );
  };
  $scope.filterByPlace = function( place ) {
    $scope.params.geoType = "place";
    $scope.currentPlace = place;
    $scope.place = $scope.currentPlace.name;
    $scope.params.place_id = $scope.currentPlace.id;
    $scope.params.swlng = null;
    $scope.params.swlat = null;
    $scope.params.nelng = null;
    $scope.params.nelat = null;
  }
  $scope.orderBy = function( order ) {
    if ($scope.params.order_by == order) {
      $scope.params.order = ($scope.params.order == 'asc' ? 'desc' : 'asc');
    } else {
      $scope.params.order_by = order;
      $scope.params.order = 'desc';
    }
  }
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


application.controller( "MapController", [ "PlacesFactory", "shared", "$scope", "$rootScope", "$anchorScroll",
function( PlacesFactory, shared, $scope, $rootScope, $anchorScroll ) {
  $rootScope.$on( "updateParamsForCurrentBounds", function( event, force ) {
    $scope.updateParamsForCurrentBounds( force );
  });
  $rootScope.$on( "offsetCenter", function( event, lat, lng ) {
    $scope.map.setCenter( shared.offsetCenter( $scope.map, $scope.map.getCenter( ), lat, lng ) );
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
    $scope.$parent.currentPlace = null;
    $scope.$parent.params.place_id = null;
  };
  $rootScope.$on( "updateMapForPlace", function( event, place ) {
    if( place && $scope.map ) {
      if( place.geometry.viewport ) {
        $scope.map.fitBounds( place.geometry.viewport );
      } else {
        $scope.map.setCenter( place.geometry.location );
        $scope.map.setZoom( 15 );
      }
      $rootScope.$emit( "offsetCenter", 130, 20 );
      $rootScope.$emit( "searchForBestPlace" );
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
  $rootScope.$on( "searchForBestPlace", function( event ) {
    if( !$scope.map ) { return; }
    // search a little left and north of center
    var center = shared.offsetCenter( $scope.map, $scope.map.getCenter( ), -130, -20 );
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
    PlacesFactory.nearby( { lat: lat, lng: lng, admin_level: admin_level, radius: boundsDistance }).then( function( response ) {
      places = PlacesFactory.responseToInstances( response );
      if( places.length > 0 ) {
        $scope.$parent.nearbyPlaces = places;
        // check the nearby places for a match to searches in the last second
        if( $scope.$parent.nearbyPlaces.length > 0 && $scope.$parent.shouldMatchPlaceSearch &&
            (new Date( ).getTime( ) - $scope.$parent.placeLastSearched) < 1000 ) {
          _.each( $scope.$parent.nearbyPlaces, function( p ) {
            if( !$scope.$parent.shouldMatchPlaceSearch || !$scope.$parent.place ) { return; }
            var searchedName = ( _.isObject( $scope.$parent.place ) ?
              $scope.$parent.place.name : $scope.$parent.place ).toLowerCase( );
            if( shared.stringStartsWith( p.name, searchedName ) || shared.stringStartsWith( searchedName, p.name ) ) {
              $scope.$parent.filterByPlace( p );
              $scope.$parent.shouldMatchPlaceSearch = false;
              return;
            }
          })
        }
      } else { $scope.$parent.nearbyPlaces = [ ]; }
    });
  });
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
      // adjust for the fact that fitBounds zooms out a little
      $scope.map.setZoom( $scope.map.getZoom( ) + 1 );
    }
    $scope.map.addListener( "dragend", function( ) {
      $rootScope.$emit( "searchForBestPlace" );
    });
    $scope.map.addListener( "zoom_changed", function( ) {
      $rootScope.$emit( "searchForBestPlace" );
    });
    $scope.setMapLayers( );
    $rootScope.$emit( "offsetCenter" );
    // the observation div on the map is a scrollable div in a scrollable page
    // make sure that when you scroll to the botton of that div, the page
    // doesn't start scrolling down
    $( "#obs" ).isolatedScroll( );
    $rootScope.$emit( "searchForBestPlace" );
    setTimeout( function( ) {
      // load place name and polygon from ID
      if( $scope.$parent.params.place_id ) {
        PlacesFactory.show( $scope.$parent.params.place_id ).then( function( response ) {
          places = PlacesFactory.responseToInstances( response );
          if( places.length > 0 ) {
            $scope.$parent.currentPlace = places[ 0 ];
            $scope.$parent.place = $scope.$parent.currentPlace.name;
            $scope.$parent.params.place_id = $scope.$parent.currentPlace.id;
          }
        });
      }
    }, 100)
  };
  $scope.$watch( "params", function( ) {
    $scope.setMapLayers( );
  }, true );
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
  $rootScope.$on( "hideNearbyPlace", function( event ) {
    if( $scope.nearbyPlaceLayer ) { $scope.nearbyPlaceLayer.setMap( null ); }
    $scope.nearbyPlaceLayer = null;
  });
  $scope.setMapLayers = function( ) {
    if (!$scope.map) { return };
    window.inatTaxonMap.removeObservationLayers( $scope.map, { title: "Observations" } );
    window.inatTaxonMap.addObservationLayers( $scope.map, {
      title: "Observations",
      mapStyle: "summary",
      observationLayers: [
        shared.processParams( _.clone( $scope.params ) )
      ]
    });
    // fully remove any existing data layer
    if( $scope.currentPlaceLayer ) { $scope.currentPlaceLayer.setMap( null ); }
    $scope.currentPlaceLayer = null;
    $scope.currentPlaceLayer = new google.maps.Data({ style: {
      strokeColor: '#d77a3b',
      strokeOpacity: 0.75,
      strokeWeight: 5,
      fillOpacity: 0
    }});
    // draw the polygon for the current place
    if( $scope.$parent.currentPlace ) {
      var c = { type: "Feature",
        geometry: $scope.$parent.currentPlace.geometry_geojson };
      $scope.currentPlaceLayer.addGeoJson( c );
      $scope.currentPlaceLayer.setMap( $scope.map );
      var bounds = new google.maps.LatLngBounds();
      // extend the bounds to encompass all features in the polygon
      $scope.currentPlaceLayer.forEach(function(feature) {
        shared.processPoints( feature.getGeometry( ), bounds.extend, bounds );
      });
      $scope.map.panToBounds( bounds );
      $scope.map.fitBounds( bounds );
      // move the map to a little left and north of center
      $rootScope.$emit( "offsetCenter", 130, 20 );
      $rootScope.$emit( "searchForBestPlace" );
    }
    // draw the filter bounding box
    else if( $scope.params.swlat && $scope.params.swlng &&
        $scope.params.nelat && $scope.params.nelng ) {
      $scope.currentPlaceLayer.addGeoJson({
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
      var bounds = new google.maps.LatLngBounds(
        new google.maps.LatLng( $scope.params.swlat, $scope.params.swlng ),
        new google.maps.LatLng( $scope.params.nelat, $scope.params.nelng ) );
      $scope.map.panToBounds( bounds );
      $scope.map.fitBounds( bounds );
      $scope.map.setZoom( $scope.map.getZoom( ) + 1 );
      $scope.currentPlaceLayer.setMap($scope.map)
    }
  };
}]);
