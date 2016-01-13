'use strict';

angular.module('picardy.fontawesome.demo', ['picardy.fontawesome'])
  .controller('CodeSample1Ctrl', function ($scope) {
    $scope.spinnerColor = 'forestgreen';
  })
  .controller('CodeSample2Ctrl', function ($scope, $timeout) {
    $scope.isLoading = false;

    $scope.reload = function () {
      $scope.isLoading = true;

      $timeout(function () {
        $scope.isLoading = false;
      }, 1000);
    };
  });

window.hljs.initHighlightingOnLoad();
