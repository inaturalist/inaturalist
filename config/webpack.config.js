const path = require( "path" );
const webpack = require( "webpack" );

const webpackAssetsPath = path.join( "app", "webpack" );

const config = {
  mode: "none",
  context: path.resolve( webpackAssetsPath ),
  entry: {
    // list out the various bundles we need to make for different apps
    "observations-identify": "./observations/identify/webpack-entry",
    "observations-uploader": "./observations/uploader/webpack-entry",
    "lifelists-show": "./lifelists/show/webpack-entry",
    "project-slideshow": "./project_slideshow/webpack-entry",
    "taxa-show": "./taxa/show/webpack-entry",
    "taxa-photos": "./taxa/photos/webpack-entry",
    "observations-show": "./observations/show/webpack-entry",
    "observations-torque": "./observations/torque/webpack-entry",
    "computer-vision": "./computer_vision/webpack-entry",
    "search-slideshow": "./search_slideshow/webpack-entry",
    "stats-year": "./stats/year/webpack-entry",
    "projects-form": "./projects/form/webpack-entry",
    "projects-show": "./projects/show/webpack-entry",
    "observations-compare": "./observations/compare/webpack-entry",
    "users-edit": "./users/edit/webpack-entry"
  },
  output: {
    // each bundle will be stored in app/assets/javascripts/[name].output.js
    // for inclusion in the asset pipeline, make app/assets/javascripts/[name]-bundle.js
    filename: "[name]-webpack.js",
    path: path.resolve( __dirname, "../assets/javascripts" )
  },
  resolve: {
    extensions: [".js", ".jsx"]
  },
  module: {
    rules: [
      // run everything through babel
      {
        test: /\.jsx?$/,
        loader: "babel-loader",
        query: { presets: ["@babel/preset-env", "@babel/preset-react"] }
      }
    ]
  },
  plugins: [
    new webpack.DefinePlugin( {
      "process.env.NODE_ENV": JSON.stringify( process.env.NODE_ENV )
    } )
  ]
};

module.exports = config;
