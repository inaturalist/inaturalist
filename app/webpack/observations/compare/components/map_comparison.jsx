import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
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
      config,
      updateCurrentUser
    } = this.props;
    let maps;
    const layerForQuery = query => {
      const layer = $.deparam( query.params );
      layer.color = query.color;
      layer.title = `<div style="width: 15px; height: 15px; display: inline-block; vertical-align: middle; margin-right: 5px; background-color: ${layer.color};"></div>${query.name}`;
      return layer;
    };
    if ( mapLayout === "combined" ) {
      maps = (
        <TaxonMap
          placement={`observations-compare-${mapLayout}`}
          showAllLayer={false}
          gestureHandling="auto"
          minX={bounds.swlng}
          minY={bounds.swlat}
          maxX={bounds.nelng}
          maxY={bounds.nelat}
          observationLayers={_.map( queries, layerForQuery )}
          currentUser={config.currentUser}
          updateCurrentUser={updateCurrentUser}
        />
      );
    } else {
      maps = _.map( queries, ( query, i ) => {
        const observationLayers = [layerForQuery( query )];
        const reloadKey = `map-${query.params}-${query.color}-${mapLayout}-${i}`;
        return (
          <div key={reloadKey} className="map">
            <h5>{ query.name }</h5>
            <TaxonMap
              placement={`observations-compare-${mapLayout}`}
              reloadKey={reloadKey}
              showAllLayer={false}
              gestureHandling="auto"
              minX={bounds.swlng}
              minY={bounds.swlat}
              maxX={bounds.nelng}
              maxY={bounds.nelat}
              observationLayers={observationLayers}
              currentUser={config.currentUser}
              updateCurrentUser={updateCurrentUser}
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
            { I18n.t( "views.observations.compare.combined" ) }
          </button>
          <button
            type="button"
            className={`btn btn-${mapLayout === "vertical" ? "primary" : "default"}`}
            onClick={( ) => setMapLayout( "vertical" )}
          >
            { I18n.t( "views.observations.compare.vertical" ) }
          </button>
          <button
            type="button"
            className={`btn btn-${mapLayout === "horizontal" ? "primary" : "default"}`}
            onClick={( ) => setMapLayout( "horizontal" )}
          >
            { I18n.t( "views.observations.compare.horizontal" ) }
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
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
};

MapComparison.defaultProps = {
  mapLayout: "combined",
  queries: [],
  bounds: {}
};

export default MapComparison;
