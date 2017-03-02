import _ from "lodash";
import React, { PropTypes } from "react";
/* global iNatModels */

const MapDetails = ( { observation, observationPlaces } ) => {
  if ( !observation ) { return ( <div /> ); }
  let label;
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
            { observation.positional_accuracy ? `${observation.positional_accuracy}m` : "-" }
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
          { observationPlaces.map( p => {
            if ( p.admin_level === null ) { return null; }
            let placeType;
            if ( p && iNatModels.Place.PLACE_TYPES[p.place_type] ) {
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
                <a href={ `/places/${p.slug}` }>
                  { p.display_name }
                </a>
                { label }
              </span>
            );
          } ) }
        </div>
        <div className="community">
          <span className="attr">Community Curated:</span>
          { observationPlaces.map( p => {
            if ( p.admin_level !== null ) { return null; }
            let placeType;
            if ( p && iNatModels.Place.PLACE_TYPES[p.place_type] ) {
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
                <a href={ `/places/${p.slug}` }>
                  { p.display_name }
                </a>
                { label }
              </span>
            );
          } ) }
        </div>
      </div>
    </div>
  );
};

MapDetails.propTypes = {
  observation: PropTypes.object,
  observationPlaces: PropTypes.array
};

export default MapDetails;
