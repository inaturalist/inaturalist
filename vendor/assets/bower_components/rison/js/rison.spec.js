var rison = require('./rison');
var chai = require('chai');
var expect = chai.expect;



describe('Rison', function() {

    it('Should do what the README says it does', function() {

        var encoded = rison.encode({any: "json", yes:true});

        expect(encoded).to.equal(`(any:json,yes:!t)`);

        var decoded = `(any:json,yes:!t)`;

        var decodedValue = rison.decode(decoded);

        expect(decodedValue).to.deep.equal({any:'json', yes:true});
    });

    it('Should handle deeply nested objects', function() {
        var deeplyNested = {
            A: {
                B: {
                    C: {
                        D: 'E',
                        F: 'G'
                    }
                },
                H: {
                    I: {
                        J:'K',
                        L:'M'
                    }
                }
            }
        };

        var encoded = rison.encode(deeplyNested);

        expect(encoded).to.equal(`(A:(B:(C:(D:E,F:G)),H:(I:(J:K,L:M))))`);

        var serializedDeeplyNested = `(A:(B:(C:(D:E,F:G)),H:(I:(J:K,L:M))))`;

        var deserializedDeeplyNested = rison.decode(serializedDeeplyNested);

        expect(deserializedDeeplyNested).to.deep.equal(deeplyNested);
    })
})

describe('O-Rison', function() {

    it('Should do what the README says it does', function() {

        var encoded = rison.encode_object({supportsObjects: true, ints: 435});

        expect(encoded).to.equal(`ints:435,supportsObjects:!t`);

        var decoded = `ints:435,supportsObjects:!t`;

        var decodedValue = rison.decode_object(decoded);

        expect(decodedValue).to.deep.equal({supportsObjects: true, ints: 435});
    });
})

describe('A-Rison', function() {

    it('Should do what the README says it does', function() {

        var encoded = rison.encode_array(['A', 'B', {supportsObjects: true}]);

        expect(encoded).to.equal(`A,B,(supportsObjects:!t)`);

        var decoded = `A,B,(supportsObjects:!t)`;

        var decodedValue = rison.decode_array(decoded);

        expect(decodedValue).to.deep.equal(['A', 'B', {supportsObjects:true}]);
    });
})
