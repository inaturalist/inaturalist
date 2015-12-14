// Declare app level module which depends on filters, and services
var myApp = angular.module('myApp', ['truncate']);


myApp.controller('demoController', function ($scope) {
    $scope.text = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.';
    $scope.numChars = 20;
    $scope.numWords = 5;
    $scope.breakOnWord = false;
});
