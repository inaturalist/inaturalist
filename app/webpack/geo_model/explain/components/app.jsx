import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

/* global h3 */
/* global chroma */
/* global TAXON_RAW_ENV_DATA */
/* global PRESENCE_ABSENCE_DATA */
/* global TAXON_RANGE_DATA */
/* global GEO_MODEL_TAXON */
/* global TILESERVER_PREFIX */

class App extends React.Component {
  constructor( ) {
    super( );
    this.map = null;
    this.infoWindow = new google.maps.InfoWindow( );
    this.mapLayers = { };
    this.setLayer = this.setLayer.bind( this );
    this.toggleObservationsLayer = this.toggleObservationsLayer.bind( this );
    this.setInfoWindow = this.setInfoWindow.bind( this );
  }

  componentDidMount( ) {
    const { taxon } = this.props;
    this.map = new google.maps.Map( document.getElementById( "map" ), {
      zoom: 2,
      center: { lat: 25, lng: 0 },
      mapTypeId: "terrain"
    } );

    const colorScale = chroma.scale( "YlGnBu" ).gamma( 0.35 );
    this.map.setOptions( { styles: this.baseMapStyle( ) } );

    const allData = {
      rawEnvData: _.mapValues( TAXON_RAW_ENV_DATA, v => ( {
        value: v,
        color: colorScale( v ).hex( )
      } ) ),
      presenceAbsence: _.mapValues( PRESENCE_ABSENCE_DATA, v => ( {
        value: v,
        color: colorScale( v ).hex( )
      } ) ),
      taxonRange: _.mapValues( TAXON_RANGE_DATA, v => ( {
        value: v,
        color: "#ff5eb0"
      } ) ),
      rangeComparison: this.rangeComparisonData( TAXON_RAW_ENV_DATA, TAXON_RANGE_DATA )
    };
    _.each( allData, ( data, key ) => {
      const drawLayer = new google.maps.Data( );
      drawLayer.setStyle( this.cellStyle );
      drawLayer.addGeoJson( this.geoJSONFromData( data, key ) );
      drawLayer.addListener( "click", this.setInfoWindow );
      this.mapLayers[key] = drawLayer;
      drawLayer.setMap( this.map );
    } );

    this.observationsLayer = new google.maps.ImageMapType( {
      getTileUrl: ( coord, zoom ) => (
        `${TILESERVER_PREFIX}/grid/${zoom}/${coord.x}/${coord.y}.png?verifiable=true&style=geotilegrid&tile_size=256&color=%23FF4500&taxon_id=${taxon.id}`
      ),
      tileSize: new google.maps.Size( 256, 256 )
    } );

    this.setLayer( "rawEnvData" );
  }

  setLayer( selectLayer ) {
    this.infoWindow.close( );
    _.each( this.mapLayers, ( layer, key ) => {
      layer.setMap( key === selectLayer ? this.map : null );
    } );
  }

  setInfoWindow( o ) {
    this.infoWindow.close( );
    const centroid = o.feature.getProperty( "centroid" );
    this.infoWindow.setPosition( { lat: centroid[0], lng: centroid[1] } );
    this.infoWindow.setContent( o.feature.getProperty( "popupContent" ) );
    this.infoWindow.open( { map: this.map } );
  }

  toggleObservationsLayer( ) {
    if ( this.map.overlayMapTypes.getAt( 0 ) ) {
      this.map.overlayMapTypes.removeAt( 0 );
    } else {
      this.map.overlayMapTypes.setAt( 0, this.observationsLayer );
    }
  }

  // eslint-disable-next-line class-methods-use-this
  rangeComparisonData( taxonRawEnvData, rangeData ) {
    const colorScale = chroma.scale( ["#74AC00", "#B0FF5E", "#FF5EB0"] ).mode( "lrgb" );
    const comparisonData = { };
    _.each( taxonRawEnvData, ( value, cellKey ) => {
      let compareValue = null;
      if ( value >= GEO_MODEL_TAXON.threshold ) {
        if ( rangeData[cellKey] ) {
          compareValue = 0.5;
        } else {
          compareValue = 0;
        }
      } else if ( rangeData[cellKey] ) {
        compareValue = 1;
      }
      if ( !_.isNull( compareValue ) ) {
        comparisonData[cellKey] = {
          color: colorScale( compareValue ).hex( ),
          value: compareValue
        };
      }
    } );
    _.each( rangeData, ( value, cellKey ) => {
      if ( !comparisonData[cellKey] && !taxonRawEnvData[cellKey] ) {
        comparisonData[cellKey] = {
          color: colorScale( 1 ).hex( ),
          value: 1
        };
      }
    } );
    return comparisonData;
  }

  // eslint-disable-next-line class-methods-use-this
  cellStyle( o ) {
    return {
      strokeColor: o.getProperty( "color" ),
      strokeOpacity: 0.2,
      strokeWeight: 1,
      fillColor: o.getProperty( "color" ),
      fillOpacity: 0.7
    };
  }

  // eslint-disable-next-line class-methods-use-this
  geoJSONFromData( data, key ) {
    const geoJSON = {
      type: "FeatureCollection",
      features: []
    };
    _.each( data, ( cellData, h3Index ) => {
      const hexBoundary = h3.cellToBoundary( h3Index );
      const latlng = h3.cellToLatLng( h3Index );
      if ( key === "rawEnvData" && cellData.value < GEO_MODEL_TAXON.threshold ) {
        return;
      }
      const popupData = {
        Cell: h3Index,
        Lat: latlng[0],
        Lng: latlng[1],
        Value: cellData.value
      };
      hexBoundary.reverse( );
      const geoJSONCoords = _.map( hexBoundary, arr => arr.reverse( ) );
      geoJSONCoords.push( hexBoundary[0] );
      const polygon = {
        type: "Feature",
        properties: {
          color: cellData.color,
          centroid: h3.cellToLatLng( h3Index ),
          popupContent: _.map( popupData, ( v, k ) => ( `${k}:${v}` ) ).join( "<br/>" )
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

  // eslint-disable-next-line class-methods-use-this
  baseMapStyle( ) {
    return [
      {
        elementType: "geometry",
        stylers: [{ color: "#f5f5f5" }]
      }, {
        elementType: "labels.text.fill",
        stylers: [{ color: "#616161" }]
      }, {
        elementType: "labels.text.stroke",
        stylers: [{ color: "#f5f5f5" }]
      }, {
        featureType: "administrative.land_parcel",
        elementType: "labels.text.fill",
        stylers: [{ color: "#bdbdbd" }]
      }, {
        featureType: "poi",
        elementType: "geometry",
        stylers: [{ color: "#eeeeee" }]
      }, {
        featureType: "poi",
        elementType: "labels.text.fill",
        stylers: [{ color: "#757575" }]
      }, {
        featureType: "poi.park",
        elementType: "geometry",
        stylers: [{ color: "#e5e5e5" }]
      }, {
        featureType: "poi.park",
        elementType: "labels.text.fill",
        stylers: [{ color: "#9e9e9e" }]
      }, {
        featureType: "road",
        elementType: "geometry",
        stylers: [{ color: "#ffffff" }]
      }, {
        featureType: "road.arterial",
        elementType: "labels.text.fill",
        stylers: [{ color: "#757575" }]
      }, {
        featureType: "road.highway",
        elementType: "geometry",
        stylers: [{ color: "#dadada" }]
      }, {
        featureType: "road.highway",
        elementType: "labels.text.fill",
        stylers: [{ color: "#616161" }]
      }, {
        featureType: "road.local",
        elementType: "labels.text.fill",
        stylers: [{ color: "#9e9e9e" }]
      }, {
        featureType: "transit.line",
        elementType: "geometry",
        stylers: [{ color: "#e5e5e5" }]
      }, {
        featureType: "transit.station",
        elementType: "geometry",
        stylers: [{ color: "#eeeeee" }]
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
  }

  render( ) {
    const { taxon } = this.props;
    const buttons = [];
    buttons.push( (
      <button
        type="button"
        key="rawEnvData"
        onClick={( ) => this.setLayer( "rawEnvData" )}
      >
        Raw Env
      </button>
    ) );
    buttons.push( (
      <button
        type="button"
        key="presenceAbsence"
        onClick={( ) => this.setLayer( "presenceAbsence" )}
      >
        Presence Absence
      </button>
    ) );
    if ( !_.isEmpty( TAXON_RANGE_DATA ) ) {
      buttons.push( (
        <button
          type="button"
          key="taxonRange"
          onClick={( ) => this.setLayer( "taxonRange" )}
        >
          Taxon Range
        </button>
      ) );
      buttons.push( (
        <button
          type="button"
          key="rangeComparison"
          onClick={( ) => this.setLayer( "rangeComparison" )}
        >
          Range Comparison
        </button>
      ) );
    }
    buttons.push( (
      <button
        type="button"
        key="observations"
        onClick={( ) => this.toggleObservationsLayer( )}
      >
        Toggle Observations
      </button>
    ) );

    return (
      <div id="TaxonGeoExplain" className="container">
        <h2>{ taxon.name }</h2>
        <div id="map" />
        <div id="controls">
          { buttons }
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
