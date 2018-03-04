import React, { PropTypes } from "react";
import _ from "lodash";
import { scaleOrdinal, schemeCategory10 } from "d3";
import TaxonMap from "../../../observations/identify/components/taxon_map";

class MapComparison extends React.Component {
  componentDidMount( ) {
    if ( this.props.mapLayout !== "combined" ) {
      this.bindMapMoveEvents( );
    }
  }
  componentDidUpdate( prevProps ) {
    if ( this.props.mapLayout !== prevProps.mapLayout && this.props.mapLayout !== "combined" ) {
      this.bindMapMoveEvents( );
    }
  }

  bindMapMoveEvents( ) {
    $( ".MapComparison .TaxonMap" ).each( ( i, elt ) => {
      const map = $( elt ).data( "taxonMap" );
      map.addListener( "drag", ( ) => {
        $( ".MapComparison .TaxonMap" ).each( ( j, otherElt ) => {
          if ( i !== j ) {
            $( otherElt ).data( "taxonMap" ).setCenter( map.getCenter( ) );
          }
        } );
      } );
      map.addListener( "zoom_changed", ( ) => {
        $( ".MapComparison .TaxonMap" ).each( ( j, otherElt ) => {
          if ( i !== j && $( otherElt ).data( "taxonMap" ).getZoom( ) !== map.getZoom( ) ) {
            $( otherElt ).data( "taxonMap" ).setZoom( map.getZoom( ) );
          }
        } );
      } );
    } );
  }
  render( ) {
    const { mapLayout, setMapLayout, queries, bounds } = this.props;
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
          showAllLayer={ false }
          gestureHandling="auto"
          minX={ bounds.swlng }
          minY={ bounds.swlat }
          maxX={ bounds.nelng }
          maxY={ bounds.nelat }
          observationLayers={ _.map( queries, layerForQuery ) }
        />
      );
    } else {
      maps = _.map( queries, query => (
        <div key={ `map-${query.params}-${mapLayout}` } className="map">
          <h5>{ query.name }</h5>
          <TaxonMap
            showAllLayer={ false }
            gestureHandling="auto"
            minX={ bounds.swlng }
            minY={ bounds.swlat }
            maxX={ bounds.nelng }
            maxY={ bounds.nelat }
            observationLayers={ [layerForQuery( query )] }
          />
        </div>
      ) );
    }
    return (
      <div className="MapComparison">
        <div className="btn-group stacked" role="group" aria-label="Map Layout Controls">
          <button
            className={ `btn btn-${!mapLayout || mapLayout === "combined" ? "primary" : "default"}` }
            onClick={ ( ) => setMapLayout( "combined" ) }
          >
            Combined
          </button>
          <button
            className={ `btn btn-${mapLayout === "vertical" ? "primary" : "default"}` }
            onClick={ ( ) => setMapLayout( "vertical" ) }
          >
            Vertical
          </button>
          <button
            className={ `btn btn-${mapLayout === "horizontal" ? "primary" : "default"}` }
            onClick={ ( ) => setMapLayout( "horizontal" ) }
          >
            Horizontal
          </button>
        </div>
        <div className={ `maps maps-${mapLayout}` }>
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
  bounds: PropTypes.object
};

export default MapComparison;
