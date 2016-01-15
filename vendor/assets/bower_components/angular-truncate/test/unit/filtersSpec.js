/*global module, inject, beforeEach, expect, describe, it */

'use strict';

describe('truncate', function () {

    beforeEach(module('truncate'));

    describe('characters', function () {
        var characterFilter;

        beforeEach(inject(function ($filter) {
            characterFilter = $filter('characters');
        }));

        it('should do nothing to this string', function () {
            expect(characterFilter('1234567890')).toEqual('1234567890');
        });

        it('should fail', function () {
            expect(characterFilter(null, 30)).toNotEqual('1234567890');
        });

        it('should not trim these down', function () {
            expect(characterFilter('1234567890', 30)).toEqual('1234567890');
        });

        it('should trim these down', function () {
            expect(characterFilter('1234567890', 5)).toEqual('12345…');
        });

        it('should trim this down including the space', function () {
            expect(characterFilter('123456789 10 11 12 13 14', 13)).toEqual('123456789 10…');
        });

        it('should trim this down breaking on words', function () {
            expect(characterFilter('123456789 10 11 12 13 14', 14,true)).toEqual('123456789 10 1…');
        });

        it('should trim this down ignoring the space', function () {
            expect(characterFilter('Florida/New Jersey/California/Texas', 30, true)).toEqual('Florida/New Jersey/California/…');
        });

        it('should handle invalid numbers', function () {
            expect(characterFilter('1234567890', 0)).toEqual('');
        });

        it('should handle invalid chars numbers type', function () {
            expect(characterFilter('1234567890', 'abc')).toEqual('1234567890');
        });
    });

    describe('words', function () {
        var wordFilter;

        beforeEach(inject(function ($filter) {
            wordFilter = $filter('words');
        }));

        it('should do nothing to this string', function () {
            expect(wordFilter('1234567890')).toEqual('1234567890');
        });

        it('should do nothing to this multi words string', function () {
            expect(wordFilter('1234567890 abc def')).toEqual('1234567890 abc def');
        });

        it('should fail', function () {
            expect(wordFilter(null, 30)).toNotEqual('1234567890');
        });

        it('should not trim these down', function () {
            expect(wordFilter('1234567890', 1)).toEqual('1234567890');
        });

        it('should trim these down', function () {
            expect(wordFilter('abc def ghhi jkl mno pqr stu vw xyz', 5)).toEqual('abc def ghhi jkl mno…');
        });

        it('should trim these down and handle multi-spaces', function () {
            expect(wordFilter('abc def    ghhi jkl    mno pqr stu    vw   xyz', 5)).toEqual('abc def ghhi jkl mno…');
        });

        it('should not trim invalid words numbers', function () {
            expect(wordFilter('abc def ghhi jkl mno pqr stu vw xyz', 0)).toEqual('');
        });

        it('should not trim invalid words type', function () {
            expect(wordFilter('hello how u doin', 'abc')).toEqual('hello how u doin');
        });

        it('should not trim higher words numbers', function () {
            expect(wordFilter('abc def ghhi jkl mno pqr stu vw xyz', 25)).toEqual('abc def ghhi jkl mno pqr stu vw xyz');
        });

    });

    describe('splitcharacters', function () {
        var characterFilter;

        beforeEach(inject(function ($filter) {
            characterFilter = $filter('splitcharacters');
        }));

        it('should do nothing to this string', function () {
            expect(characterFilter('1234567890')).toEqual('1234567890');
        });

        it('should fail', function () {
            expect(characterFilter(null, 30)).toNotEqual('1234567890');
        });

        it('should not trim these down', function () {
            expect(characterFilter('1234567890', 30)).toEqual('1234567890');
        });

        it('should trim these down', function () {
            expect(characterFilter('1234567890', 5)).toEqual('12...890');
        });

        it('should trim this down including the space', function () {
            expect(characterFilter('123456789 10 11 12 13 14', 13)).toEqual('123456...2 13 14');
        });

        it('should handle invalid numbers', function () {
            expect(characterFilter('1234567890', 0)).toEqual('');
        });

        it('should handle invalid chars numbers type', function () {
            expect(characterFilter('1234567890', 'abc')).toEqual('1234567890');
        });
    });
});
