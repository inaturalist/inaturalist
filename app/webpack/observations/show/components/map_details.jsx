import _ from "lodash";
import React, { PropTypes } from "react";
/* global iNatModels */

class MapDetails extends React.Component {

  placeList( places ) {
    return places.map( p => {
      let label;
      let placeType;
      if ( p && p.place_type && iNatModels.Place.PLACE_TYPES[p.place_type] ) {
        placeType = I18n.t( `place_geo.geo_planet_place_types.${
          _.snakeCase( iNatModels.Place.PLACE_TYPES[p.place_type] )}` );
      }
      label = placeType && (
        <span className="type">
          { _.upperFirst( placeType ) }
        </span>
      );
      return (
        <span className="place" key={ `place-${p.id}` }>
          <a href={ `/observations?place_id=${p.id}` }>
            { p.display_name }
          </a>
          { label }
        </span>
      );
    } );
  }

  render( ) {
    const { observation, observationPlaces } = this.props;
    if ( !observation ) { return ( <div /> ); }
    return (
      <div className="MapDetails">
        <div className="top_info">
          <div className="info">
            <span className="attr">Lat:</span>&nbsp;
            <span className="value">{ _.round( observation.latitude, 6 ) }</span>
          </div>
          <div className="info">
            <span className="attr">Lon:</span>&nbsp;
            <span className="value">{ _.round( observation.longitude, 6 ) }</span>
          </div>
          <div className="info">
            <span className="attr">Accuracy:</span>&nbsp;
            <span className="value">
              { observation.positional_accuracy ?
                `${observation.positional_accuracy}m` : "Not Recorded" }
            </span>
          </div>
          <div className="info">
            <span className="attr">Geoprivacy:</span>&nbsp;
            <span className="value">
              { observation.obscured ? "Obscured" : ( observation.geoprivacy || "Open" ) }
            </span>
          </div>
        </div>
        <div className="places">
          <h4>Encompassing Places</h4>
          <div className="standard">
            <span className="attr">Standard:</span>
            { this.placeList( observationPlaces.filter( op => ( op.admin_level !== null ) ) ) }
          </div>
          <div className="community">
            <span className="attr">Community Curated:</span>
            { this.placeList( observationPlaces.filter( op => ( op.admin_level === null ) ) ) }
          </div>
        </div>
      </div>
    );
  }
}

MapDetails.propTypes = {
  observation: PropTypes.object,
  observationPlaces: PropTypes.array
};

export default MapDetails;
