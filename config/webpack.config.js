const path = require( "path" );
const webpack = require( "webpack" );

const webpackAssetsPath = path.join( "app", "webpack" );

const config = {
  mode: process.env.RAILS_ENV === "production" ? "production" : "none",
  target: ["web", "es5"],
  context: path.resolve( webpackAssetsPath ),
  entry: {
    "computer-vision": {
      import: "./computer_vision/webpack-entry",
      dependOn: ["react-main", "react-dropzone"]
    },
    "geo-model-explain": {
      import: "./geo_model/explain/webpack-entry",
      dependOn: ["react-main"]
    },
    "geo-model-index": {
      import: "./geo_model/index/webpack-entry",
      dependOn: ["react-main"]
    },
    "lifelists-show": {
      import: "./lifelists/show/webpack-entry",
      dependOn: ["react-main", "user-text"]
    },
    "observations-compare": {
      import: "./observations/compare/webpack-entry",
      dependOn: ["react-main", "d3"]
    },
    "observations-identify": {
      import: "./observations/identify/webpack-entry",
      dependOn: ["react-main", "react-image-gallery", "user-text"]
    },
    "observations-show": {
      import: "./observations/show/webpack-entry",
      dependOn: ["react-main", "react-dropzone", "react-image-gallery", "user-text"]
    },
    "observations-torque": {
      import: "./observations/torque/webpack-entry",
      dependOn: ["react-main"]
    },
    "observations-uploader": {
      import: "./observations/uploader/webpack-entry",
      dependOn: ["react-main", "react-dnd", "react-dropzone"]
    },
    "projects-form": {
      import: "./projects/form/webpack-entry",
      dependOn: ["react-main", "react-dropzone"]
    },
    "project-slideshow": {
      import: "./project_slideshow/webpack-entry",
      dependOn: ["react-main"]
    },
    "projects-show": {
      import: "./projects/show/webpack-entry",
      dependOn: ["react-main", "d3", "user-text"]
    },
    "search-slideshow": {
      import: "./search_slideshow/webpack-entry",
      dependOn: ["react-main"]
    },
    "stats-year": {
      import: "./stats/year/webpack-entry",
      dependOn: ["react-main", "d3"]
    },
    "taxa-photos": {
      import: "./taxa/photos/webpack-entry",
      dependOn: ["react-main", "react-dnd"]
    },
    "taxa-show": {
      import: "./taxa/show/webpack-entry",
      dependOn: ["react-main", "d3", "user-text"]
    },
    "users-edit": {
      import: "./users/edit/webpack-entry",
      dependOn: ["react-main", "react-dnd", "react-dropzone"]
    },
    "react-main": {
      import: [
        "core-js/stable",
        "regenerator-runtime",
        "lodash",
        "inaturalistjs",
        "moment-timezone",
        "prop-types",
        "react",
        "react-dom",
        "react-dom/server",
        "react-redux",
        "redux-thunk",
        "redux",
        "react-bootstrap",
        "./shared/util",
        "./shared/ducks/config"
      ],
      runtime: "runtime"
    },
    "d3": {
      import: ["d3"],
      runtime: "runtime"
    },
    "react-dnd": {
      import: ["react-dnd"],
      runtime: "runtime"
    },
    "react-dropzone": {
      import: ["react-dropzone"],
      runtime: "runtime"
    },
    "react-image-gallery": {
      import: ["react-image-gallery"],
      runtime: "runtime"
    },
    "user-text": {
      import: [
        "html-truncate",
        "linkifyjs/html",
        "sanitize-html",
        "markdown-it"
      ],
      runtime: "runtime"
    }
  },
  output: {
    // each bundle will be stored in app/assets/javascripts/webpack/[name]-webpack.js
    filename: "[name]-webpack.js",
    path: path.resolve( __dirname, "../app/assets/javascripts/webpack" )
  },
  resolve: {
    extensions: [".js", ".jsx"],
    fallback: {
      querystring: require.resolve( "querystring-es3" ),
      punycode: require.resolve( "punycode" )
    }
  },
  module: {
    rules: [
      // run everything through babel
      {
        test: /\.c?jsx?$/,
        loader: "babel-loader",
        resolve: {
          fullySpecified: false
        },
        options: {
          presets: [
            "@babel/preset-env",
            "@babel/preset-react"
          ]
        }
      }
    ]
  },
  plugins: [
    // Some dependencies seem to expect process.env.NODE_ENV to be defined,
    // particularly in development
    new webpack.DefinePlugin( {
      "process.env.NODE_ENV": JSON.stringify(
        process.env.RAILS_ENV || process.env.NODE_ENV
      )
    } )
  ]
};

module.exports = config;
