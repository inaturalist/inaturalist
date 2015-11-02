'use strict';

// I started using the default bootstrap dropdown to manage the filter opening,
// but it assumes all clicks in the dropdown should close the dropdown, so I had
// to not use the boostrap javascript there and do it myself
$(document).ready(function() {
  $('#filter-container .dropdown-toggle').click(function() {
    $(this).parent().toggleClass('open');
  });
  $('body').on('click', function(e) {
    if (!$('#filter-container').is(e.target)
        && $('#filter-container').has(e.target).length === 0
        && $('.open').has(e.target).length === 0) {
      $('#filter-container').removeClass('open');
    };
  });
});

/**
 * @ngdoc overview
 * @name ObservationSearchPrototype
 * @description
 * # ObservationSearchPrototype
 *
 * Main module of the application.
 */
angular
  .module('ObservationSearchPrototype', [
    'ngResource',
    'iNatResources',
    'google.places'
  ]);

// RESOURCES
// Using angular's $resource service to wrap our API. Here only wrapping GET
// requests to /observations
var iNatResources = angular.module('iNatResources', ['ngResource']);
iNatResources.factory('Observation', ['$resource', function($resource) {
  var paramDefaults = {};
  var actions = {
    query: {
      method: 'GET',
      isArray: true,
      url: '/observations.json'
    }
  };
  return $resource('/observations/:id.json', paramDefaults, actions);
}]);

// CONTROLLERS

// MainCtrl controls the dislay of the observations. Note that while the
// filters are stored in the $rootScope, which is shared by all controllers in
// the app, observations themselves are isolated to the MainCtrl
angular.module('ObservationSearchPrototype').controller('MainCtrl', ['$scope', '$rootScope', 'Observation', function ($scope, $rootScope, Observation) {
  // Translates the params stored in the $rootScope into params suitable for
  // an API request. I tried to make the filters just match the API exactly,
  // but angular doesn't seem to make that easy for multi-value params like
  // iconic_taxa[]. There are also some UI elements that have state but don't
  // need to be included in API requests, like the kind of date filter being
  // applied. I suspect there are more "angular" ways to deal with this
  function reloadObservations() {
    var processedParams = angular.copy($rootScope.params)
    // deal with iconic taxa
    if (processedParams._iconic_taxa) {
      var iconic_taxa = [];
      angular.forEach(processedParams._iconic_taxa, function(selected, name) {
        if (selected) {
          iconic_taxa.push(name)
        }
      });
      processedParams.iconic_taxa = iconic_taxa;
      delete processedParams._iconic_taxa;
    }
    // deal with has
    var has = [], matches, keysToDelete = [];
    angular.forEach(processedParams, function(v, k) {
      matches = k.match(/has_(\w+)/)
      if (matches && v) {
        has.push(matches[1]);
        keysToDelete.push(k);
      }
    });
    processedParams.has = has;
    angular.forEach(keysToDelete, function(k) {
      delete processedParams[k]
    })
    // date types
    // this looks and feels horrible, but I'm not sure what the angular way of doing it would be
    switch( processedParams.dateType ) {
      case 'exact':
        delete processedParams.d1;
        delete processedParams.d2;
        delete processedParams.month;
        break;
      case 'range':
        delete processedParams.on;
        delete processedParams.month;
        break;
      case 'month':
        delete processedParams.on;
        delete processedParams.d1;
        delete processedParams.d2;
        break;
      default:
        delete processedParams.on;
        delete processedParams.d1;
        delete processedParams.d2;
        delete processedParams.month;
    }
    delete processedParams.dateType;
    switch( processedParams.geoType ) {
      case 'place':
        delete processedParams.swlng;
        delete processedParams.swlat;
        delete processedParams.nelng;
        delete processedParams.nelat;
        break;
      case 'map':
        delete processedParams.place_id;
        break;
      default:
        delete processedParams.swlng;
        delete processedParams.swlat;
        delete processedParams.nelng;
        delete processedParams.nelat;
        delete processedParams.place_id;
    }
    delete processedParams.geoType;
    // console.log("[DEBUG] processedParams: ", processedParams);
    $scope.observations = Observation.query(processedParams);
    if ($rootScope.map) {
      window.inatTaxonMap.removeObservationLayers($rootScope.map, {title: 'Observations'});
      window.inatTaxonMap.addObservationLayers($rootScope.map, {
        title: 'Observations',
        mapStyle: 'summary',
        observationLayers: [
          processedParams
        ]
      })
    }
  }
  
  // Initialize UI elements outside of angular. In theory these could be re-
  // implemented as angular directives. I played with some of the angular
  // Google Maps directives out there, e.g. https://github.com/allenhwkim
  // /angularjs-google-maps, but of course they don't make it easy to
  // incorporate our custom tiles and UTFGrid tiles.
  angular.element(document).ready(function () {
    $('#filters input[name="taxon_name"]').taxonAutocomplete({
      taxon_id_el: $('#filters input[name="taxon_id"]'),
      afterSelect: function(result) {
        $rootScope.params.taxon_id = result.item.id;
        $rootScope.$digest();
      },
      afterUnselect: function() {
        $rootScope.params.taxon_id = null;
        $rootScope.$digest();
      }
    })
    $("#map").taxonMap({
      urlCoords: true, 
      mapType: google.maps.MapTypeId.TERRAIN,
      showLegend: true,
      showAllLayer: false
    });
    $rootScope.map = $("#map").data("taxonMap");
    var onChangedBounds = function() {
      var bounds = $rootScope.map.getBounds(),
          ne     = bounds.getNorthEast(),
          sw     = bounds.getSouthWest();
      $rootScope.params.swlng = sw.lng();
      $rootScope.params.swlat = sw.lat();
      $rootScope.params.nelng = ne.lng();
      $rootScope.params.nelat = ne.lat();
      // $rootScope.$$phase tests to see whether the rootScope is currently
      // being digested. Without this, you get way too many events firing off
      // when you drag the map
      if(!$rootScope.$$phase) {
        $rootScope.$digest();
      }
    }
    $rootScope.map.addListener('dragend', onChangedBounds);
    $rootScope.map.addListener('zoom_changed', onChangedBounds);
    reloadObservations();
  });
  
  // reload observations whenever params change
  var deepObjectComparison = true; // without this the params hash will always appear the same when its values change
  $rootScope.$watch('params', function(newValue, oldValue) {
    reloadObservations();
  }, deepObjectComparison);
}]);

// FiltersCtrl manages the filters box. It doesn't have much of a local state,
// but does set the defaults for the params in the $rootScope
angular.module('ObservationSearchPrototype').controller('FiltersCtrl', ['$scope', '$rootScope', function ($scope, $rootScope) {
  $rootScope.params = $rootScope.params || {};
  // $rootScope.params.captive = false;
  $rootScope.params.has_photos = true;
  $rootScope.params.order_by = 'observations.id';
  $rootScope.params.order = 'desc';
  $rootScope.params.dateType = 'any';
  $rootScope.params.geoType = 'world';
  
  $scope.$watch('place', function() {
    if ($scope.place && $scope.place.geometry && $rootScope.map) {
      $rootScope.params.geoType = 'map';
      if ($scope.place.geometry.viewport) {
        $rootScope.map.fitBounds($scope.place.geometry.viewport);
      } else {
        $rootScope.map.setCenter($scope.place.geometry.location);
        $rootScope.map.setZoom(15);
      }
    } else {
      $rootScope.params.geoType = 'world';
    }
  });
}]);
