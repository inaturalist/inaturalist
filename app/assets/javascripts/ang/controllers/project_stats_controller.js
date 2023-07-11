/* globals _ */
/* globals angular */
/* globals I18n */
/* globals iNatModels */
/* globals iNaturalist */

var application = angular.module( "ProjectStats", [
  "templates",
  "iNatAPI"
] );

// used for displaying HTML returned from methods
application.filter( "sanitize", ["$sce", function ( $sce ) {
  return function ( safeHTML ) {
    return $sce.trustAsHtml( safeHTML );
  };
}] );

application.controller( "ProjectStatsController", ["ObservationsFactory", "shared", "$scope",
  function ( ObservationsFactory, shared, $scope ) {
    $scope.shared = shared;
    // confusingly, this value gets set with /projects/show.js when it
    // fetches observations. The project observations display on projects
    // show still uses a Rails endpoint, so that JS was left alone for now.
    $scope.observationsCount = "?";
    $scope.speciesCount = "?";
    $scope.observersCount = "?";
    $scope.userObservationsLink = function ( u ) {
      return I18n.t( "x_observations_link_html", {
        count: u.observation_count,
        url: $scope.searchURL + "&user_id=" + u.login
      } );
    };
    $scope.userSpeciesLink = function ( u ) {
      return I18n.t( "x_species_link_html", {
        count: u.species_count,
        url: $scope.searchURL + "&user_id=" + u.login
          + "&hrank=species&view=species"
      } );
    };
    $scope.taxonObservationsLink = function ( t ) {
      return I18n.t( "x_observations_link_html", {
        count: t.result_count,
        url: $scope.searchURL + "&taxon_id=" + t.id
      } );
    };
    $scope.initParams = function ( p ) {
      $scope.observationSearchParams = _.extend( { }, p );
    };
    $scope.$watch( "observationSearchParams", function ( ) {
      var statsParams = _.extend(
        {},
        $scope.observationSearchParams,
        iNaturalist.localeParams( ),
        { per_page: 5 }
      );
      $scope.searchURL = "/observations?" + $.param( $scope.observationSearchParams );
      ObservationsFactory.speciesCounts( statsParams ).then( function ( response ) {
        $scope.speciesCount = response.data.total_results;
        $scope.taxa = _.map( response.data.results, function ( r ) {
          var t = new iNatModels.Taxon( r.taxon );
          t.result_count = r.count;
          return t;
        } );
      } );
      ObservationsFactory.observers( _.extend( {}, statsParams, { per_page: 200 } ) )
        .then( function ( response ) {
          $scope.observersCount = response.data.total_results;
          $scope.observers = _.map( response.data.results.slice( 0, 5 ), function ( r ) {
            var u = new iNatModels.User( r.user );
            u.observation_count = r.observation_count;
            return u;
          } );
          $scope.speciesObservers = _.map(
            _.reverse( _.sortBy( response.data.results, "species_count" ) ).slice( 0, 5 ),
            function ( r ) {
              var u = new iNatModels.User( r.user );
              u.species_count = r.species_count;
              return u;
            }
          );
        } );
    } );
  }] );
