var path = require('path'),
    webpack = require("webpack");
    webpack_assets_path = path.join('app', 'webpack');

var config = {
  context: path.resolve(webpack_assets_path),
  // entry: './webpack/entry.js',
  entry: {
    // list out the various bundles we need to make for different apps
    'observations-identify': './observations/identify/webpack-entry',
    'observations-uploader': './observations/uploader/webpack-entry',
    'project-slideshow': './project_slideshow/webpack-entry',
    'taxa-show': './taxa/show/webpack-entry',
    'taxa-photos': './taxa/photos/webpack-entry'
  },
  output: {
    // each bundle will be stored in app/assets/javascripts/[name].output.js
    // for inclusion in the asset pipeline, make app/assets/javascripts/[name]-bundle.js
    filename: '[name]-webpack.js',
    path: path.resolve(__dirname, "../assets/javascripts"),
  },
  // externals: {
  //   jquery: 'var jQuery'
  // },
  resolve: {
    extensions: ['', '.js', '.jsx'],
    root: path.resolve(webpack_assets_path)
  },
  module: {
    loaders: [
      // run everything through babel. See .babelrc for babel-specific
      // configs, include react defaults that allow it to deal with jsx
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        loader: 'babel-loader',
        query: { presets: [ "es2015", "react" ] }
      },
      { test: /\.json$/, loader: "json-loader" }
    ]
  },
  plugins: [
    new webpack.DefinePlugin({
      "process.env.NODE_ENV": JSON.stringify(process.env.NODE_ENV)
    })
  ]
};
module.exports = config;
