var gulp = require('gulp'),
    gulpUtil = require('gulp-util'),
    webpack = require('webpack-stream');

gulp.task("webpack", function() {
  // return gulp.src("app/assets/javascripts/webpack/entry.js")
  // Usually you'd hand a single entry files to src(), but we define multiple
  // entry points in the config file, so we hand it a blank
  return gulp.src("")
    .pipe(webpack(require("./config/webpack.config.js")))
    .pipe(gulp.dest("app/assets/javascripts/"));
});

gulp.task("watch", function() {
  fatalLevel = 'off';
  gulp.watch([
    // all js files in the webpack dir
    "app/assets/javascripts/webpack/**/*.js",

    // all jsx files in the webback dir
    "app/assets/javascripts/webpack/**/*.jsx"
  ], ["webpack"]);
});

gulp.task("default", ["webpack", "watch"]);
