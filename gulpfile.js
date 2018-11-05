const gulp = require( "gulp" );
const webpack = require( "webpack-stream" );
const webpackConfig = require( "./config/webpack.config.js" );

const webpackTask = ( ) => (
  gulp.src( "./" )
    .pipe( webpack( webpackConfig ) )
    .pipe( gulp.dest( "app/assets/javascripts/" ) )
);

const watchTask = ( ) => {
  gulp.watch( [
    // all js files in the webpack dir
    "app/webpack/**/*.js",

    // all jsx files in the webback dir
    "app/webpack/**/*.jsx"
  ], { interval: 1000 }, webpackTask );
};

gulp.task( "default", gulp.series( webpackTask, watchTask ) );
gulp.task( "webpack", webpackTask );
