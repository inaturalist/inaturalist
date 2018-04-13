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
    let accuracy = observation.private_geojson ?
      observation.positional_accuracy : observation.public_positional_accuracy;
    let accuracyUnits = "m";
    if ( accuracy > 1000 ) {
      accuracy = _.round( accuracy / 1000, 2 );
      accuracyUnits = "km";
    }
    let geoprivacy = I18n.t( "open_" );
    if ( observation.geoprivacy === "private" ) {
      geoprivacy = I18n.t( "private_" );
    } else if ( observation.obscured ) {
      geoprivacy = I18n.t( "obscured" );
    } else if ( observation.geoprivacy ) {
      geoprivacy = I18n.t( observation.geoprivacy );
    }
    return (
      <div className="MapDetails">
        <div className="top_info">
          <div className="info">
            <span className="attr">{ I18n.t( "lat" ) }:</span>&nbsp;
            <span className="value">{ _.round( observation.latitude, 6 ) }</span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "long" ) }:</span>&nbsp;
            <span className="value">{ _.round( observation.longitude, 6 ) }</span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "accuracy" ) }:</span>&nbsp;
            <span className="value">
              { accuracy ? `${accuracy}${accuracyUnits}` : I18n.t( "not_recorded" ) }
            </span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "geoprivacy" ) }:</span>&nbsp;
            <span className="value">{ geoprivacy }</span>
          </div>
        </div>
        <div className="places">
          <h4>{ I18n.t( "encompassing_places" ) }</h4>
          <div className="standard">
            <span className="attr">{ I18n.t( "standard" ) }:</span>
            { this.placeList( observationPlaces.filter( op => ( op.admin_level !== null ) ) ) }
          </div>
          <div className="community">
            <span className="attr">{ I18n.t( "community_curated" ) }:</span>
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
