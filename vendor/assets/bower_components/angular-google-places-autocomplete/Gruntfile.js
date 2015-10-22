/*
 * angular-google-places-autocomplete
 *
 * Copyright (c) 2014 "kuhnza" David Kuhn
 * Licensed under the MIT license.
 * https://github.com/kuhnza/angular-google-places-autocomplete/blob/master/LICENSE
 */

'use strict';

module.exports = function (grunt) {
	// Load grunt tasks automatically
	require('load-grunt-tasks')(grunt);

	grunt.initConfig({
		karma: {
			unit: {
				configFile: 'karma.conf.js',
				singleRun: true
			}
		},
		clean: {
			dist: { src: 'dist', dot: true },
            lib: { src: 'example/lib', dot: true },
			bower: { src: 'bower_components', dot: true }
		},
		bower: { 
			install: { options: { targetDir: 'example/lib' } } 
		},
        cssmin: {
            dist: {
                expand: true,
                cwd: 'dist/',
                files: {
                    'dist/autocomplete.min.css': 'src/autocomplete.css'
                }
            }
        },
		uglify: {
			dist: {
				files: {
					'dist/autocomplete.min.js': 'src/autocomplete.js'
				}
			}
		}
	});

	grunt.registerTask('test', [
		'karma'
	]);

	grunt.registerTask('build', [
		'clean',
		'bower',
        'cssmin',
		'uglify'
	]);

	grunt.registerTask('default', ['build']);
};
