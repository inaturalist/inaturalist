import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { scaleOrdinal, schemeCategory10 } from "d3";
import TaxonMap from "../../identify/components/taxon_map";

class MapComparison extends React.Component {
  static bindMapMoveEvents( ) {
    $( ".MapComparison .TaxonMap" ).not( ".map-move-bound" ).each( ( i, elt ) => {
      const map = $( elt ).data( "taxonMap" );
      if ( !map ) {
        return;
      }
      map.addListener( "drag", ( ) => {
        $( ".MapComparison .TaxonMap" ).each( ( j, otherElt ) => {
          if ( i !== j ) {
            $( otherElt ).data( "taxonMap" ).setCenter( map.getCenter( ) );
          }
        } );
      } );
      map.addListener( "zoom_changed", ( ) => {
        const newZoom = map.getZoom( );
        const newCenter = map.getCenter( );
        $( ".MapComparison .TaxonMap" ).each( ( j, otherElt ) => {
          const otherMap = $( otherElt ).data( "taxonMap" );
          if ( !otherMap ) {
            return;
          }
          if ( i !== j && otherMap.getZoom( ) !== newZoom ) {
            otherMap.setCenter( newCenter );
            otherMap.setZoom( newZoom );
          }
        } );
      } );
      $( elt ).addClass( "map-move-bound" );
    } );
  }

  componentDidMount( ) {
    const { mapLayout } = this.props;
    if ( mapLayout !== "combined" ) {
      MapComparison.bindMapMoveEvents( );
    }
  }

  componentDidUpdate( ) {
    const { mapLayout } = this.props;
    if ( mapLayout !== "combined" ) {
      MapComparison.bindMapMoveEvents( );
    }
  }

  render( ) {
    const {
      mapLayout,
      setMapLayout,
      queries,
      bounds,
      config
    } = this.props;
    let maps;
    const colorScale = scaleOrdinal( schemeCategory10 );
    const layerForQuery = query => {
      const layer = $.deparam( query.params );
      layer.color = colorScale( query.params );
      layer.title = `<div style="width: 15px; height: 15px; display: inline-block; vertical-align: middle; margin-right: 5px; background-color: ${layer.color};"></div>${query.name}`;
      return layer;
    };
    if ( mapLayout === "combined" ) {
      maps = (
        <TaxonMap
          showAllLayer={false}
          gestureHandling="auto"
          minX={bounds.swlng}
          minY={bounds.swlat}
          maxX={bounds.nelng}
          maxY={bounds.nelat}
          observationLayers={_.map( queries, layerForQuery )}
          currentUser={config.currentUser}
        />
      );
    } else {
      maps = _.map( queries, ( query, i ) => {
        const observationLayers = [layerForQuery( query )];
        const reloadKey = `map-${query.params}-${mapLayout}-${i}`;
        return (
          <div key={reloadKey} className="map">
            <h5>{ query.name }</h5>
            <TaxonMap
              reloadKey={reloadKey}
              showAllLayer={false}
              gestureHandling="auto"
              minX={bounds.swlng}
              minY={bounds.swlat}
              maxX={bounds.nelng}
              maxY={bounds.nelat}
              observationLayers={observationLayers}
            />
          </div>
        );
      } );
    }
    return (
      <div className="MapComparison">
        <div className="btn-group stacked" role="group" aria-label="Map Layout Controls">
          <button
            type="button"
            className={`btn btn-${!mapLayout || mapLayout === "combined" ? "primary" : "default"}`}
            onClick={( ) => setMapLayout( "combined" )}
          >
            { I18n.t( "combined" ) }
          </button>
          <button
            type="button"
            className={`btn btn-${mapLayout === "vertical" ? "primary" : "default"}`}
            onClick={( ) => setMapLayout( "vertical" )}
          >
            { I18n.t( "vertical" ) }
          </button>
          <button
            type="button"
            className={`btn btn-${mapLayout === "horizontal" ? "primary" : "default"}`}
            onClick={( ) => setMapLayout( "horizontal" )}
          >
            { I18n.t( "horizontal" ) }
          </button>
        </div>
        <div className={`maps maps-${mapLayout}`}>
          { maps }
        </div>
      </div>
    );
  }
}

MapComparison.propTypes = {
  mapLayout: PropTypes.string,
  setMapLayout: PropTypes.func,
  queries: PropTypes.array,
  bounds: PropTypes.object,
  config: PropTypes.object
};

MapComparison.defaultProps = {
  mapLayout: "combined",
  queries: [],
  bounds: {}
};

export default MapComparison;
