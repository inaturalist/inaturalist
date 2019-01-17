import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
/* global iNatModels */

class MapDetails extends React.Component {
  static placeList( places ) {
    return places.map( p => {
      let placeType;
      if ( p && p.place_type && iNatModels.Place.PLACE_TYPES[p.place_type] ) {
        placeType = I18n.t( `place_geo.geo_planet_place_types.${
          _.snakeCase( iNatModels.Place.PLACE_TYPES[p.place_type] )}` );
      }
      const label = placeType && (
        <span className="type">
          { _.upperFirst( placeType ) }
        </span>
      );
      return (
        <span className="place" key={`place-${p.id}`}>
          <a href={`/observations?place_id=${p.id}`}>
            { p.display_name }
          </a>
          { label }
        </span>
      );
    } );
  }

  render( ) {
    const { observation, observationPlaces, config } = this.props;
    const { currentUser } = config;
    if ( !observation ) { return ( <div /> ); }
    let accuracy = observation.private_geojson
      ? observation.positional_accuracy : observation.public_positional_accuracy;
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
    const currentUserHasProjectCuratorCoordinateAccess = _.find(
      observation.project_observations,
      po => (
        po.preferences
        && po.preferences.allows_curator_coordinate_access
        && po.project.admins.map( a => a.user_id ).indexOf( currentUser.id ) >= 0
      )
    );
    return (
      <div className="MapDetails">
        <div className="top_info">
          <div className="info">
            <span className="attr">{ I18n.t( "lat" ) }:</span>
            { " " }
            <span className="value">{ _.round( observation.latitude, 6 ) }</span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "long" ) }:</span>
            { " " }
            <span className="value">{ _.round( observation.longitude, 6 ) }</span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "accuracy" ) }:</span>
            { " " }
            <span className="value">
              { accuracy ? `${accuracy}${accuracyUnits}` : I18n.t( "not_recorded" ) }
            </span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "geoprivacy" ) }:</span>
            { " " }
            <span className="value">{ geoprivacy }</span>
          </div>
        </div>
        <div className="places clearfix">
          <h4>{ I18n.t( "encompassing_places" ) }</h4>
          <div className="standard">
            <span className="attr">{ I18n.t( "standard" ) }:</span>
            { MapDetails.placeList( observationPlaces.filter( op => ( op.admin_level !== null ) ) ) }
          </div>
          <div className="community">
            <span className="attr">{ I18n.t( "community_curated" ) }:</span>
            { MapDetails.placeList( observationPlaces.filter( op => ( op.admin_level === null ) ) ) }
          </div>
        </div>
        { observation.obscured && (
          <div className="obscured">
            <h4>Why the Coordinates Are Obscured</h4>
            <ul>
              { observation.geoprivacy === "obscured" && (
                <li>
                  <strong>Geoprivacy is obscured:</strong>
                  { " " }
                  observer has chosen to obscure the coordinates.
                </li>
              ) }
              { observation.geoprivacy === "private" && (
                <li>
                  <strong>Geoprivacy is private:</strong>
                  { " " }
                  observer has chosen to hide the coordinates.
                </li>
              ) }
              { observation.taxon_geoprivacy === "obscured" && (
                <li>
                  <strong>Taxon is threatened, coordinates obscured by default:</strong>
                  { " " }
                  this taxon is known to be rare and/or threatened so its location has been obscured.
                </li>
              ) }
              { observation.taxon_geoprivacy === "private" && (
                <li>
                  <strong>Taxon is threatened, coordinates hidden by default:</strong>
                  { " " }
                  this taxon is known to extremelely vulnerable to human exploitation so its location has been obscured.
                </li>
              ) }
            </ul>
            <h4>Who Can See the Coordinates</h4>
            <ul>
              <li>The person who made the observation</li>
              <li>iNaturalist staff</li>
              <li>
                Curators of the following projects:
                <ul>
                  { _.filter(
                    observation.project_observations,
                    po => po.preferences && po.preferences.allows_curator_coordinate_access
                  ).map( po => (
                    <li key={`map-details-projects-${po.id}`}>{ po.project.title }</li>
                  ) ) }
                </ul>
              </li>
            </ul>
            { observation.geojson && (
              <div>
                <h4>Why You Can See the Coordinates</h4>
                <ul>
                  { currentUser && currentUser.id === observation.user.id && (
                    <li><strong>This is your observation: </strong> You can always see the coordinates of your own observations.</li>
                  ) }
                  { currentUserHasProjectCuratorCoordinateAccess && (
                    <li>
                      <strong>You curate a project that contains this observation: </strong>
                      You can see obscured coordinates when you curate a
                      project that contains an observation and the observer has
                      chosen to share coordinates with curators of that project.
                    </li>
                  ) }
                </ul>
              </div>
            ) }
          </div>
        ) }
        <div className="links">
          <span className="attr">{ I18n.t( "view_on" ) }</span>
          <span>
            <span className="info">
              <a
                className="value"
                href={`https://www.google.com/maps?q=loc:${observation.latitude},${observation.longitude}`}
              >
                { I18n.t( "google" ) }
              </a>
            </span>
            <span className="info">
              <a
                className="value"
                href={`https://www.openstreetmap.org/?mlat=${observation.latitude}&mlon=${observation.longitude}`}
              >
                { I18n.t( "open_street_map" ) }
              </a>
            </span>
            {/*
              Nice to have, but sort of useless unless macrostrat implements the abililty to link to the infowindow
              and not just the coords
              <span className="info">
                <a className="value" href={ `https://macrostrat.org/map/#5/${observation.latitude}/${observation.longitude}` }>
                  { I18n.t( "macrostrat" ) }
                </a>
              </span>
            */}
          </span>
        </div>
      </div>
    );
  }
}

MapDetails.propTypes = {
  observation: PropTypes.object,
  observationPlaces: PropTypes.array,
  config: PropTypes.object
};

MapDetails.defaultProps = {
  config: {}
};

export default MapDetails;
