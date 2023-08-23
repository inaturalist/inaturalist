import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import chroma from "chroma-js";
import { cellToBoundary, cellToLatLng } from "h3-js";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonMap from "../../../observations/identify/components/taxon_map";

/* global GEO_MODEL_CELL_SCORES */
/* global TAXON_RANGE_DATA */
/* global GEO_MODEL_TAXON */

const urlParams = new URLSearchParams( window.location.search );

const NEARBY_COLOR = urlParams.get( "nearby_color" ) || "#007DFF";
const RANGE_COLOR = urlParams.get( "range_color" ) || "#FF5EB0";
const OVERLAP_COLOR = urlParams.get( "overlap_color" ) || "#ADA3E8";
const SCORE_COLOR_LOWER = urlParams.get( "score_color_lower" ) || NEARBY_COLOR;
const SCORE_COLOR_UPPER = urlParams.get( "score_color_upper" ) || NEARBY_COLOR;

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
    chroma( lowColor ).alpha( 0 ),
    chroma( lowColor ).alpha( 1 ),
    chroma( highColor ).alpha( 1 )
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
    const { taxon } = this.props;
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
      geomodelCellScores: _.mapValues( GEO_MODEL_CELL_SCORES, v => ( {
        value: v,
        color: colorScale( logStretch( v, min, max ) ),
        opacity: 0.9
      } ) ),
      expectedNearbyData: _.mapValues( GEO_MODEL_CELL_SCORES, v => ( {
        opacity: 0.6,
        value: v,
        color: NEARBY_COLOR
      } ) ),
      rangeComparison: this.rangeComparisonData( )
    };
    let bounds;
    _.each( allData, ( data, key ) => {
      const drawLayer = new google.maps.Data( );
      drawLayer.setStyle( this.cellStyle );
      const threshold = key === "expectedNearbyData" ? GEO_MODEL_TAXON.threshold : null;
      const dataGeoJson = this.geoJSONFromData( data, key, threshold );
      drawLayer.addGeoJson( dataGeoJson );
      if ( key === "geomodelCellScores" ) {
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

    this.setState( { layer: "geomodelCellScores" } );
    this.map.fitBounds( bounds );
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
  rangeComparisonData( ) {
    const comparisonData = { };
    // add data for all cells in the geo model
    _.each( GEO_MODEL_CELL_SCORES, ( value, cellKey ) => {
      if ( value < GEO_MODEL_TAXON.threshold ) {
        return;
      }
      comparisonData[cellKey] = {
        color: TAXON_RANGE_DATA[cellKey] ? OVERLAP_COLOR : NEARBY_COLOR,
        opacity: TAXON_RANGE_DATA[cellKey] ? 0.8 : 0.6
      };
    } );
    // add data for all taxon range cells not also in the geo model
    _.each( TAXON_RANGE_DATA, ( value, cellKey ) => {
      if ( !comparisonData[cellKey] && !GEO_MODEL_CELL_SCORES[cellKey] ) {
        comparisonData[cellKey] = {
          color: RANGE_COLOR,
          value: 1,
          opacity: 0.6
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
        className={`btn btn-default${this.state.layer === "geomodelCellScores" ? " active" : ""}`}
        type="button"
        key="geomodelCellScores"
        onClick={( ) => this.setState( { layer: "geomodelCellScores" } )}
      >
        Geomodel Score Map
      </button>
    ) );
    buttons.push( (
      <button
        className={`btn btn-default${this.state.layer === "expectedNearbyData" ? " active" : ""}`}
        type="button"
        key="expectedNearbyData"
        onClick={( ) => this.setState( { layer: "expectedNearbyData" } )}
      >
        Expected Nearby Map
      </button>
    ) );
    if ( !_.isEmpty( TAXON_RANGE_DATA ) ) {
      buttons.push( (
        <button
          className={`btn btn-default${this.state.layer === "rangeComparison" ? " active" : ""}`}
          type="button"
          key="rangeComparison"
          onClick={( ) => this.setState( { layer: "rangeComparison" } )}
        >
          Expected Nearby Evaluation
        </button>
      ) );
    }

    return (
      <div id="TaxonGeoExplain" className="container">
        <h1>
          GeoModel Predictions of
          <SplitTaxon
            taxon={taxon}
            user={config.currentUser}
            url={`/taxa/${taxon.id}`}
          />
        </h1>
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
          showLegend
        />
        <div className="container">
          <div className="row">
            <div id="controls" className="btn-group">
              { buttons }
            </div>
          </div>
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
