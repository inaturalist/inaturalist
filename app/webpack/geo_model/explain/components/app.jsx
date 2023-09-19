import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
import chroma from "chroma-js";
import { cellToBoundary, cellToLatLng } from "h3-js";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonMap from "../../../observations/identify/components/taxon_map";

/* global GEO_MODEL_CELL_SCORES */
/* global TAXON_RANGE_DATA */
/* global GEO_MODEL_TAXON */
/* global EXPECTED_NEARBY_FIGURE_URL */
/* global WEIGHTING_FIGURE_URL */
/* global RANGE_COMPARISON_FIGURE_URL */

const urlParams = new URLSearchParams( window.location.search );

const NEARBY_COLOR = urlParams.get( "nearby_color" ) || "#007DFF";
const NEARBY_OPACITY = urlParams.get( "nearby_opacity" ) || 0.4;
const RANGE_COLOR = urlParams.get( "range_color" ) || "#FF5EB0";
const RANGE_OPACITY = urlParams.get( "range_opacity" ) || 0.4;
const OVERLAP_COLOR = urlParams.get( "overlap_color" ) || "#5A57D1";
const OVERLAP_OPACITY = urlParams.get( "overlap_opacity" ) || 0.8;
const SCORE_COLOR_LOWER = urlParams.get( "score_color_lower" ) || "#97CAFF";
const SCORE_OPACITY_LOWER = urlParams.get( "score_opacity_lower" ) || 0;
const SCORE_COLOR_UPPER = urlParams.get( "score_color_upper" ) || "#1574D8";
const SCORE_OPACITY_UPPER = urlParams.get( "score_opacity_upper" ) || 1;
const SCORE_OPACITY = urlParams.get( "score_opacity" ) || 0.9;

const logStretch = ( value, min, max ) => (
  ( Math.log( value ) - Math.log( min ) ) / ( Math.log( max ) - Math.log( min ) )
);

const baseMapStyle = [
  {
    stylers: [
      { lightness: 50 },
      { saturation: -100 }
    ]
  }, {
    elementType: "geometry",
    stylers: [{ color: "#f5f5f5" }]
  }, {
    elementType: "labels.text.fill",
    stylers: [{ color: "#616161" }]
  }, {
    elementType: "labels.text.stroke",
    stylers: [{ color: "#f5f5f5" }]
  }, {
    featureType: "water",
    elementType: "geometry",
    stylers: [{ color: "#d9d9d9" }]
  }, {
    featureType: "water",
    elementType: "labels.text.fill",
    stylers: [{ color: "#9e9e9e" }]
  }
];

const customColorScale = ( lowColor, highColor, min, max ) => {
  const baseScale = chroma.scale( [
    chroma( lowColor ).alpha( Number( SCORE_OPACITY_LOWER ) ),
    chroma( lowColor ).alpha( Number( SCORE_OPACITY_UPPER ) ),
    chroma( highColor ).alpha( Number( SCORE_OPACITY_UPPER ) )
  ] ).domain( [min, max] );
  return chroma.scale( [baseScale( min ), baseScale( max )] );
};

class App extends React.Component {
  constructor( ) {
    super( );
    this.map = null;
    this.mapLayers = { };
    this.setLayer = this.setLayer.bind( this );
    this.state = { };
  }

  componentDidMount( ) {
    this.map = $( ".TaxonMap", ReactDOM.findDOMNode( this ) ).data( "taxonMap" );
    this.map.setOptions( {
      styles: baseMapStyle,
      minZoom: 2,
      mapTypeControl: false
    } );
    const max = _.max( _.values( GEO_MODEL_CELL_SCORES ) );
    const min = _.min( _.values( GEO_MODEL_CELL_SCORES ) );
    const colorScale = customColorScale( SCORE_COLOR_LOWER, SCORE_COLOR_UPPER, min, max );
    const allData = {
      unthresholdedMap: _.mapValues( GEO_MODEL_CELL_SCORES, v => ( {
        value: v,
        color: colorScale( logStretch( v, min, max ) ),
        opacity: SCORE_OPACITY
      } ) ),
      expectedNearbyData: _.mapValues( GEO_MODEL_CELL_SCORES, v => ( {
        opacity: NEARBY_OPACITY,
        value: v,
        color: NEARBY_COLOR
      } ) ),
      expectedNearbyVsTaxonRange: this.expectedNearbyVsTaxonRangeData( )
    };
    let bounds;
    _.each( allData, ( data, key ) => {
      const drawLayer = new google.maps.Data( );
      drawLayer.setStyle( this.cellStyle );
      const threshold = key === "expectedNearbyData" ? GEO_MODEL_TAXON.threshold : null;
      const dataGeoJson = this.geoJSONFromData( data, key, threshold );
      drawLayer.addGeoJson( dataGeoJson );
      if ( key === "unthresholdedMap" ) {
        const latitudes = _.map( dataGeoJson.features, f => ( f.properties.centroid[0] ) );
        const minLat = _.min( latitudes );
        const maxLat = _.max( latitudes );
        const longitudes = _.map( dataGeoJson.features, f => ( f.properties.centroid[1] ) );
        const minLng = _.min( longitudes );
        const maxLng = _.max( longitudes );
        bounds = new google.maps.LatLngBounds(
          new google.maps.LatLng( minLat, minLng ),
          new google.maps.LatLng( maxLat, maxLng )
        );
      }
      this.mapLayers[key] = drawLayer;
      drawLayer.setMap( this.map );
      drawLayer.setStyle( this.cellStyle );
    } );

    this.setState( { layer: "expectedNearbyData" } );
    this.map.fitBounds( bounds );
    // TODO: terrible hack to get tile layers to render over data layers
    // After transition these data layers to tile layers, this can be removed
    setTimeout( ( ) => (
      $( $( "[aria-label='Map'] > div:first > div:first" )[0] ).css( "zIndex", 500 )
    ), 1000 );
  }

  componentDidUpdate( prevProps, prevState ) {
    const { layer } = this.state;
    if ( prevState.layer !== layer ) {
      this.setLayer( layer );
    }
  }

  setLayer( selectLayer ) {
    _.each( this.mapLayers, ( layer, key ) => {
      layer.setMap( key === selectLayer ? this.map : null );
    } );
  }

  // eslint-disable-next-line class-methods-use-this
  expectedNearbyVsTaxonRangeData( ) {
    const comparisonData = { };
    // add data for all cells in the geo model
    _.each( GEO_MODEL_CELL_SCORES, ( value, cellKey ) => {
      if ( value < GEO_MODEL_TAXON.threshold ) {
        return;
      }
      comparisonData[cellKey] = {
        color: TAXON_RANGE_DATA[cellKey] ? OVERLAP_COLOR : NEARBY_COLOR,
        opacity: TAXON_RANGE_DATA[cellKey] ? OVERLAP_OPACITY : NEARBY_OPACITY
      };
    } );
    // add data for all taxon range cells not also in the geo model
    _.each( TAXON_RANGE_DATA, ( value, cellKey ) => {
      if ( !comparisonData[cellKey] ) {
        comparisonData[cellKey] = {
          color: RANGE_COLOR,
          value: 1,
          opacity: RANGE_OPACITY
        };
      }
    } );
    return comparisonData;
  }

  // eslint-disable-next-line class-methods-use-this
  cellStyle( o ) {
    return {
      strokeColor: o.getProperty( "color" ),
      strokeOpacity: o.getProperty( "opacity" ) / 5,
      strokeWeight: 1,
      fillColor: o.getProperty( "color" ),
      fillOpacity: o.getProperty( "opacity" ) || 0.7,
      clickable: false,
      optimized: false,
      zIndex: -1
    };
  }

  // eslint-disable-next-line class-methods-use-this
  geoJSONFromData( data, key, threshold = null ) {
    const geoJSON = {
      type: "FeatureCollection",
      features: []
    };
    _.each( data, ( cellData, h3Index ) => {
      if ( threshold && cellData.value < threshold ) {
        return;
      }
      const hexBoundary = cellToBoundary( h3Index );
      const latlng = cellToLatLng( h3Index );
      // Google maps doesn't show map data near the poles, so dont include values in that range
      if ( latlng[0] > 85 || latlng[0] < -85 ) {
        return;
      }
      hexBoundary.reverse( );
      const geoJSONCoords = _.map( hexBoundary, arr => arr.reverse( ) );
      geoJSONCoords.push( hexBoundary[0] );
      const polygon = {
        type: "Feature",
        properties: {
          color: cellData.color,
          opacity: cellData.opacity,
          centroid: latlng
        },
        geometry: {
          type: "Polygon",
          coordinates: [geoJSONCoords]
        }
      };
      geoJSON.features.push( polygon );
    } );
    return geoJSON;
  }

  render( ) {
    const { taxon, config } = this.props;
    const buttons = [];
    buttons.push( (
      <button
        className={`btn btn-default${this.state.layer === "expectedNearbyData" ? " active" : ""}`}
        type="button"
        key="expectedNearbyData"
        onClick={( ) => this.setState( { layer: "expectedNearbyData" } )}
      >
        { I18n.t( "views.geo_model.explain.nearby_map.expected_nearby_map" ) }
      </button>
    ) );
    buttons.push( (
      <button
        className={`btn btn-default${this.state.layer === "unthresholdedMap" ? " active" : ""}`}
        type="button"
        key="unthresholdedMap"
        onClick={( ) => this.setState( { layer: "unthresholdedMap" } )}
      >
        { I18n.t( "views.geo_model.explain.unthresholded_map.unthresholded_map" ) }
      </button>
    ) );
    if ( !_.isEmpty( TAXON_RANGE_DATA ) ) {
      buttons.push( (
        <button
          className={`btn btn-default${this.state.layer === "expectedNearbyVsTaxonRange" ? " active" : ""}`}
          type="button"
          key="expectedNearbyVsTaxonRange"
          onClick={( ) => this.setState( { layer: "expectedNearbyVsTaxonRange" } )}
        >
          { I18n.t( "views.geo_model.explain.range_comparison.expected_nearby_vs_taxon_range" ) }
        </button>
      ) );
    }

    let tabDescription;
    if ( this.state.layer === "unthresholdedMap" ) {
      tabDescription = (
        <div>
          <p>
            { I18n.t( "views.geo_model.explain.unthresholded_map.we_use_the_unthresholded_map" ) }
          </p>
          <p
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.geo_model.explain.unthresholded_map.for_example" )
            }}
          />
          <p className="figure">
            <img
              alt={I18n.t( "views.geo_model.explain.unthresholded_map.figure_alt_text" )}
              src={WEIGHTING_FIGURE_URL}
            />
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.unthresholded_map.you_can_think" ) }
          </p>
        </div>
      );
    } else if ( this.state.layer === "expectedNearbyData" ) {
      tabDescription = (
        <div>
          <p>
            { I18n.t( "views.geo_model.explain.nearby_map.we_use_this_map" ) }
          </p>
          <p
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.geo_model.explain.nearby_map.for_example" )
            }}
          />
          <p className="figure">
            <img
              alt={I18n.t( "views.geo_model.explain.nearby_map.figure_alt_text" )}
              src={EXPECTED_NEARBY_FIGURE_URL}
            />
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.nearby_map.you_can_think" ) }
          </p>
        </div>
      );
    } else if ( this.state.layer === "expectedNearbyVsTaxonRange" ) {
      const precision = _.round( GEO_MODEL_TAXON.precision, 2 );
      const recall = _.round( GEO_MODEL_TAXON.recall, 2 );
      const f1 = _.round( GEO_MODEL_TAXON.f1, 2 );
      tabDescription = (
        <div>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.this_map_shows" ) }
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.this_gridded_version" ) }
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.by_combining" ) }
          </p>
          <p className="figure comparison">
            <img
              alt={I18n.t( "views.geo_model.explain.range_comparison.figure_alt_text" )}
              src={RANGE_COMPARISON_FIGURE_URL}
            />
          </p>
          <p>
            { I18n.t( "views.geo_model.explain.range_comparison.combining_these_maps_produces" ) }
          </p>
          <div className="row color-legend">
            <div className="col-xs-12">
              <div className="color-box" style={{ backgroundColor: NEARBY_COLOR, opacity: NEARBY_OPACITY }} />
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.false_presences_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.false_presences_definition" ) }
            </div>
          </div>
          <div className="row color-legend">
            <div className="col-xs-12">
              <div className="color-box" style={{ backgroundColor: RANGE_COLOR, opacity: RANGE_OPACITY }} />
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.false_absences_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.false_absences_definition" ) }
            </div>
          </div>
          <div className="row color-legend">
            <div className="col-xs-12">
              <div className="color-box" style={{ backgroundColor: OVERLAP_COLOR, opacity: OVERLAP_OPACITY }} />
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.true_presences_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.true_presences_definition" ) }
            </div>
          </div>
          <div className="row">
            <div
              className="col-xs-12 evaluation-header"
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.geo_model.explain.range_comparison.evaluation_statistics_for_taxon", {
                  taxon: ReactDOMServer.renderToString(
                    <SplitTaxon
                      taxon={taxon}
                      user={config.currentUser}
                      url={`/taxa/${taxon.id}`}
                    />
                  )
                } )
              }}
            />
          </div>
          <div className="row stat-description">
            <div className="col-xs-12">
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.precision_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.precision_description" ) }
              <br />
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.geo_model.explain.range_comparison.precision_equation", {
                    precision: ReactDOMServer.renderToString( <span className="strong-label">{precision}</span> )
                  } )
                }}
              />
            </div>
          </div>
          <div className="row stat-description">
            <div className="col-xs-12">
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.recall_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.recall_description" ) }
              <br />
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.geo_model.explain.range_comparison.recall_equation", {
                    recall: ReactDOMServer.renderToString( <span className="strong-label">{recall}</span> )
                  } )
                }}
              />
            </div>
          </div>
          <div className="row stat-description">
            <div className="col-xs-12">
              <span className="strong-label">
                { I18n.t( "views.geo_model.explain.range_comparison.f1_colon" ) }
              </span>
              { I18n.t( "views.geo_model.explain.range_comparison.f1_description" ) }
              <br />
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.geo_model.explain.range_comparison.f1_equation", {
                    f1: ReactDOMServer.renderToString( <span className="strong-label">{f1}</span> )
                  } )
                }}
              />
            </div>
          </div>
          <div className="row">
            <div className="col-xs-12">
              { I18n.t( "views.geo_model.explain.range_comparison.perfect_overlap" ) }
            </div>
          </div>
        </div>
      );
    }

    return (
      <div id="TaxonGeoExplain" className="container">
        <h1
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.geo_model.explain.geomodel_predictions_of_taxon", {
              taxon: ReactDOMServer.renderToString(
                <SplitTaxon
                  taxon={taxon}
                  user={config.currentUser}
                  url={`/taxa/${taxon.id}`}
                />
              )
            } )
          }}
        />
        <p>
          { I18n.t( "views.geo_model.explain.the_geo_model_makes_predictions" ) }
        </p>
        <p dangerouslySetInnerHTML={{
          __html: I18n.t( "views.geo_model.explain.the_geo_model_is_trained", { url: "/blog" } )
        }}
        />
        <TaxonMap
          placement="taxa-show"
          showAllLayer={false}
          taxonLayers={[{
            taxon,
            observationLayers: [{
              label: "Verifiable Observations",
              verifiable: true,
              disabled: true
            }],
            ranges: "disabled"
          }]}
          gestureHandling="auto"
          mapType={google.maps.MapTypeId.TERRAIN}
          showLegend
        />
        <div className="container">
          <div className="row">
            <div id="controls" className="btn-group">
              { buttons }
            </div>
          </div>
        </div>
        <div className="tab-description">
          { tabDescription }
        </div>
      </div>
    );
  }
}

App.propTypes = {
  taxon: PropTypes.object,
  config: PropTypes.object
};

App.defaultProps = {
  config: {}
};

export default App;
