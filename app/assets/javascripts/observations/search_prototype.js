'use strict';

$(document).ready(function() {
  $('#filters .dropdown-menu').click(function(e) {
      e.stopPropagation();
  });
})

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
    'iNatResources'
  ]);

// RESOURCES
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
angular.module('ObservationSearchPrototype').controller('MainCtrl', ['$scope', '$rootScope', 'Observation', function ($scope, $rootScope, Observation) {
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
    delete processedParams.dateType;
    console.log("[DEBUG] processedParams: ", processedParams);
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
  
  angular.element(document).ready(function () {
    // $('input[name="taxon_id"]').taxonAutocomplete()
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
      $rootScope.$digest();
    }
    $rootScope.map.addListener('dragend', onChangedBounds);
    $rootScope.map.addListener('zoom_changed', onChangedBounds);
    reloadObservations();
  });

  var deepObjectComparison = true; // without this the params hash will always appear the same when its values change
  $rootScope.$watch('params', function(newValue, oldValue) {
    reloadObservations();
  }, deepObjectComparison);
}]);

angular.module('ObservationSearchPrototype').controller('FiltersCtrl', ['$scope', '$rootScope', function ($scope, $rootScope) {
  $rootScope.params = $rootScope.params || {};
  $rootScope.params.captive = false;
  $rootScope.params.has_photos = true;
  $rootScope.params.order_by = 'observations.id';
  $rootScope.params.order = 'desc';
  $rootScope.params.dateType = 'any';
  $rootScope.params.geoType = 'world';
}]);
