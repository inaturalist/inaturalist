/*
 * angular-google-places-autocomplete
 *
 * Copyright (c) 2014 "kuhnza" David Kuhn
 * Licensed under the MIT license.
 * https://github.com/kuhnza/angular-google-places-autocomplete/blob/master/LICENSE
 */

'use strict';


// Sample set of AutocompleteService predictions
var PREDICTIONS = [
    {
        "description": "18 Elizabeth Street, Waterloo, New South Wales, Australia",
        "id": "7ff2649b9154e8649a2516c95aa8cf6cc93a813f",
        "matched_substrings": [
            {
                "length": 4,
                "offset": 0
            }
        ],
        "place_id": "ChIJTV3MUSCuEmsRmsdcXOWqjqsSOTE4IEVsaXphYmV0aCBTdHJlZXQsIFdhdGVybG9vLCBOZXcgU291dGggV2FsZXMsIEF1c3RyYWxpYQ",
        "reference": "CkQ9AAAAy3q7MwWKLBbOECg7_AABUyvfIA_UagPLlfKtRvB-Lb5JiTr_HQ-h_eqJ6kFgKTpkakpVxsnbe-qDa_g7Ot3zUhIQG3deNdBjROdh1GOclW50bBoUCuBA9EPr3XZO9WSsjqJgGzpPXqA",
        "terms": [
            {
                "offset": 0,
                "value": "18 Elizabeth Street"
            },
            {
                "offset": 21,
                "value": "Waterloo"
            },
            {
                "offset": 31,
                "value": "New South Wales"
            },
            {
                "offset": 48,
                "value": "Australia"
            }
        ],
        "types": [ "route", "geocode" ]
    },
    {
        "description": "18 Enmore Road, Newtown, New South Wales, Australia",
        "id": "565bbf7706c54cce1f892cbafefc6536a8511401",
        "matched_substrings": [
            {
                "length": 4,
                "offset": 0
            }
        ],
        "place_id": "ChIJBXTUmUewEmsRLURHiC6_kPESMzE4IEVubW9yZSBSb2FkLCBOZXd0b3duLCBOZXcgU291dGggV2FsZXMsIEF1c3RyYWxpYQ",
        "reference": "CkQ3AAAAGQ7efGL9QoxL-F6acCMBSflEN6a0x1ZGJJo5vJcZ0IHjVZVN3O4NUe2r1EQBJeolHTIj1I4A9f_NKlrB6-uNMRIQNJ93FN3UnjdZXe_MyREqdhoUH7lpHAddLM9XD4K08jh3e9KYuGk",
        "terms": [
            {
                "offset": 0,
                "value": "18 Enmore Road"
            },
            {
                "offset": 16,
                "value": "Newtown"
            },
            {
                "offset": 25,
                "value": "New South Wales"
            },
            {
                "offset": 42,
                "value": "Australia"
            }
        ],
        "types": [ "route", "geocode" ]
    },
    {
        "description": "18 Edgecliff Road, Woollahra, New South Wales, Australia",
        "id": "693a0891e53897fe8927d83b673d173ed34ac6c1",
        "matched_substrings": [
            {
                "length": 4,
                "offset": 0
            }
        ],
        "place_id": "ChIJe7rePu-tEmsRUwKubnjKGYUSODE4IEVkZ2VjbGlmZiBSb2FkLCBXb29sbGFocmEsIE5ldyBTb3V0aCBXYWxlcywgQXVzdHJhbGlh",
        "reference": "CkQ8AAAAPpSTyRB1rC-zSKLViiDvWaXdXuBOcCDAXhhlF0-STTrGifuUm3ziduX-H8zye8pTMIbvJi-e4JOq5lOadBBiwRIQmeOe9clMU26I1MH26B2LgxoUiGzILgMIhpNZqF50MpDcmYK0D0Q",
        "terms": [
            {
                "offset": 0,
                "value": "18 Edgecliff Road"
            },
            {
                "offset": 19,
                "value": "Woollahra"
            },
            {
                "offset": 30,
                "value": "New South Wales"
            },
            {
                "offset": 47,
                "value": "Australia"
            }
        ],
        "types": [ "route", "geocode" ]
    },
    {
        "description": "18 Euston Road, Alexandria, New South Wales, Australia",
        "id": "01cfa48f0b27e93394f347a39b80412287e0a013",
        "matched_substrings": [
            {
                "length": 4,
                "offset": 0
            }
        ],
        "place_id": "ChIJ52QqfbOxEmsR_wTF_yJgirISNjE4IEV1c3RvbiBSb2FkLCBBbGV4YW5kcmlhLCBOZXcgU291dGggV2FsZXMsIEF1c3RyYWxpYQ",
        "reference": "CkQ6AAAAxGKnSZMdZc9kOfUmzUaTf70zXn78P4J9oZCr06YFeAgxV-Y2ulX97fwb6Al4rJzASKaADCzgQiRNFOSuTcS1txIQjXtWiEthGmN-ZM7G2nMu6RoU_ItmcK4Cm59POh3fHhi6e75_Z_c",
        "terms": [
            {
                "offset": 0,
                "value": "18 Euston Road"
            },
            {
                "offset": 16,
                "value": "Alexandria"
            },
            {
                "offset": 28,
                "value": "New South Wales"
            },
            {
                "offset": 45,
                "value": "Australia"
            }
        ],
        "types": [ "route", "geocode" ]
    },
    {
        "description": "18 Erskine Street, Sydney, New South Wales, Australia",
        "id": "69ebe34986ae44b13267116f8c4107d190ff2f01",
        "matched_substrings": [
            {
                "length": 4,
                "offset": 0
            }
        ],
        "place_id": "ChIJ8dg8UEeuEmsRvdt4xsQoZUMSNTE4IEVyc2tpbmUgU3RyZWV0LCBTeWRuZXksIE5ldyBTb3V0aCBXYWxlcywgQXVzdHJhbGlh",
        "reference": "CkQ5AAAAWpXzWfHYj6pkpo62wsJYt-3Xyc6hXWQDQSFUZO7rSaUOF_7eyuDf03v1EwSEn8c6O-UtCyKbAzwPxRZeRX-HtRIQvh7iV2yFT2Wr1hMUgIoqfRoUW9VDCDS_bMk8Yhvg1_LVxRIctxA",
        "terms": [
            {
                "offset": 0,
                "value": "18 Erskine Street"
            },
            {
                "offset": 19,
                "value": "Sydney"
            },
            {
                "offset": 27,
                "value": "New South Wales"
            },
            {
                "offset": 44,
                "value": "Australia"
            }
        ],
        "types": [ "route", "geocode" ]
    }
];


describe('Factory: googlePlacesApi', function () {

    var googlePlacesApi;

    beforeEach(module('google.places'));

    beforeEach(inject(function (_$window_, _googlePlacesApi_) {
        googlePlacesApi = _googlePlacesApi_;
    }));

    it('should load', function () {
        expect(googlePlacesApi).toBeDefined();
    });
});


describe('Directive: gPlacesAutocomplete', function () {

    var $parentScope, $isolatedScope, $compile, googlePlacesApi;

    function compileAndDigest(html) {
        var element = angular.element(html);
        $compile(element)($parentScope);
        $parentScope.$digest();
        $isolatedScope = element.isolateScope();
    }

    beforeEach(module('google.places'));

    beforeEach(inject(function ($rootScope, _$compile_) {
        $parentScope = $rootScope.$new();
        $compile = _$compile_;

        $parentScope.place = null;

        compileAndDigest('<input type="text" g-places-autocomplete ng-model="place" />');
    }));

    // TODO: write more tests!
    it('should initialize model', function () {
    });
});


describe('Directive: gPlacesAutocompleteDrawer', function () {

    var $parentScope, $isolatedScope, $compile, element;

    var template = '<div g-places-autocomplete-drawer input="input" query="query" predictions="predictions" active="active" selected="selected"></div>';

    function compileAndDigest(html) {
        element = angular.element(html);
        $compile(element)($parentScope);
        $parentScope.$digest();
        $isolatedScope = element.isolateScope();
    }

    beforeEach(module('google.places'));

    beforeEach(inject(function ($rootScope, _$compile_) {
        $parentScope = $rootScope.$new();
        $compile = _$compile_;

        $parentScope.input = angular.element('<input type="text"/>');
        $parentScope.query = '';
        $parentScope.predictions = [];
    }));


    describe('when there are no predictions', function () {

        beforeEach(function () {
            compileAndDigest(template);
        });

        it('should close drawer', function () {
            expect($isolatedScope.isOpen()).toBe(false);
        });
    });

    describe('when there are predictions', function () {

        var predictionElements;

        beforeEach(function () {
            $parentScope.predictions = angular.copy(PREDICTIONS);

            compileAndDigest(template);

            predictionElements = element.children().children();
        });

        it('should open drawer', function () {
            expect($isolatedScope.isOpen()).toBe(true);
        });

        it('should select the active prediction when hovering', function () {
            var activeElement = angular.element(predictionElements['1']);
            activeElement.triggerHandler('mouseenter');

            expect($isolatedScope.active).toBe(1);
            expect($isolatedScope.isActive(1)).toBe(true);
            expect($isolatedScope.isActive(0)).toBe(false);
        });

        it('should select the prediction on click', function () {
            var activeElement = angular.element(predictionElements['2']);
            activeElement.triggerHandler('click');

            expect($isolatedScope.selected).toBe(2);
        });

        it('should set the drawer position', function () {
            expect($isolatedScope.position).toBeDefined();
        });
    })
});


describe('Directive: gPlacesAutocompletePrediction', function () {

    var $parentScope, $isolatedScope, $compile;

    function compileAndDigest(html) {
        var element = angular.element(html);
        $compile(element)($parentScope);
        $parentScope.$digest();
        $isolatedScope = element.isolateScope();
    }

    beforeEach(module('google.places'));

    beforeEach(inject(function ($rootScope, _$compile_) {
        $parentScope = $rootScope.$new();
        $compile = _$compile_;

        $parentScope.$index = 0;
        $parentScope.prediction = angular.copy(PREDICTIONS[0]);
        $parentScope.query = '18';

        compileAndDigest('<div g-places-autocomplete-prediction index="$index" prediction="prediction" query="query"></div>');
    }));

    // TODO: write more tests!
    it('should initialize model', function () {
    });
});


describe('Filter: unmatchedTermsOnly', function () {

    var unmatchedTermsOnlyFilter;

    beforeEach(module('google.places'));

    beforeEach(inject(function (_unmatchedTermsOnlyFilter_) {
        unmatchedTermsOnlyFilter = _unmatchedTermsOnlyFilter_;
    }));

    it('should only return unmatched terms for a prediction', function () {
        var prediction = angular.copy(PREDICTIONS[0]);

        var result = unmatchedTermsOnlyFilter(prediction.terms, prediction);

        expect(result).toEqual([
            {
                "offset": 21,
                "value": "Waterloo"
            },
            {
                "offset": 31,
                "value": "New South Wales"
            },
            {
                "offset": 48,
                "value": "Australia"
            }
        ]);
    });
});


describe('Filter: trailingComma', function () {

    var trailingCommaFilter;

    beforeEach(module('google.places'));

    beforeEach(inject(function (_trailingCommaFilter_) {
        trailingCommaFilter = _trailingCommaFilter_;
    }));

    it('should append a trailing comma if condition is true', function () {
        var result = trailingCommaFilter('a string', true);

        expect(result).toEqual('a string,');
    });

    it('should omit the trailing comma if condition is false', function () {
        var result = trailingCommaFilter('a string', false);

        expect(result).toEqual('a string');
    });
});