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
      } else {
        placeType = I18n.t( "unknown" );
      }
      const label = placeType && (
        <span className="type">
          { _.upperFirst( placeType ) }
        </span>
      );
      return (
        <span className="place" key={`place-${p.id}`}>
          <a href={`/observations?place_id=${p.id}`}>
            { I18n.t( `places_name.${_.snakeCase( p.name )}`, {
              defaultValue: p.display_name || p.name
            } ) }
          </a>
          { label }
        </span>
      );
    } );
  }

  constructor( ) {
    super( );
    this.state = {
      showAllPlaces: false
    };
  }

  render( ) {
    const {
      observation,
      observationPlaces,
      config
    } = this.props;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    const { showAllPlaces } = this.state;
    const { currentUser } = config;
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
    } else if ( observation.geoprivacy === "obscured" ) {
      geoprivacy = I18n.t( "obscured" );
    } else if ( observation.geoprivacy ) {
      geoprivacy = I18n.t( observation.geoprivacy );
    }
    const projectObservationsWithCoordinateAccess = _.filter(
      observation.project_observations,
      po => po.preferences && po.preferences.allows_curator_coordinate_access
    );
    const projectsWithCoordinateAccess = _.map(
      projectObservationsWithCoordinateAccess, po => po.project
    );
    _.forEach( observation.non_traditional_projects, ntp => {
      if ( ntp.project_user ) {
        const observerTrustsProjectWithAnyObservation = ntp.project_user
          .prefers_curator_coordinate_access_for === "any";
        const observerTrustsProjectWithThreatenedTaxa = ntp.project_user
          .prefers_curator_coordinate_access_for === "taxon";
        const obscuredByObserver = ["obscured", "private"].includes( observation.geoprivacy );
        const obscuredByTaxon = ["obscured", "private"].includes( observation.taxon_geoprivacy );
        if (
          observerTrustsProjectWithAnyObservation
          || (
            observerTrustsProjectWithThreatenedTaxa
            && !obscuredByObserver
            && obscuredByTaxon
          )
        ) {
          projectsWithCoordinateAccess.push( ntp.project );
        }
      }
    } );
    let currentUserHasProjectCuratorCoordinateAccess;
    if ( currentUser && currentUser.id ) {
      currentUserHasProjectCuratorCoordinateAccess = _.find(
        projectsWithCoordinateAccess,
        project => project.admins.map( a => a.user_id ).includes( currentUser.id )
      );
    }
    const adminPlaces = observationPlaces.filter( op => ( op.admin_level !== null ) );
    const communityPlaces = observationPlaces.filter( op => ( op.admin_level === null ) );
    const defaultNumberOfCommunityPlaces = 10;
    const obscurationExplanationGeoprivacy = (
      <li>
        <strong>
          <i className="icon-icn-location-obscured" />
          { I18n.t( "label_colon", { label: I18n.t( "geoprivacy_is_obscured" ) } ) }
        </strong>
        { " " }
        { I18n.t( "geoprivacy_is_obscured_desc" ) }
      </li>
    );
    return (
      <div className="MapDetails">
        <div className="top_info">
          <div className="info">
            <span className="attr">{ I18n.t( "label_colon", { label: I18n.t( "lat" ) } ) }</span>
            { " " }
            <span className="value">{ _.round( observation.latitude, 6 ) || "" }</span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "label_colon", { label: I18n.t( "long" ) } ) }</span>
            { " " }
            <span className="value">{ _.round( observation.longitude, 6 ) || "" }</span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "label_colon", { label: I18n.t( "accuracy" ) } ) }</span>
            { " " }
            <span className="value">
              { accuracy ? `${accuracy}${accuracyUnits}` : I18n.t( "not_recorded" ) }
            </span>
          </div>
          <div className="info">
            <span className="attr">{ I18n.t( "label_colon", { label: I18n.t( "geoprivacy" ) } ) }</span>
            { " " }
            <span className="value">{ geoprivacy }</span>
          </div>
        </div>
        <div className="places clearfix">
          <h4>{ I18n.t( "encompassing_places" ) }</h4>
          <div className="standard">
            <span className="attr">{ I18n.t( "label_colon", { label: I18n.t( "standard" ) } ) }</span>
            { MapDetails.placeList( adminPlaces ) }
          </div>
          <div className="community">
            <span className="attr">{ I18n.t( "label_colon", { label: I18n.t( "community_curated" ) } ) }</span>
            { communityPlaces.lenght < defaultNumberOfCommunityPlaces ? (
              MapDetails.placeList( communityPlaces )
            ) : (
              <div>
                { MapDetails.placeList( communityPlaces.slice(
                  0,
                  showAllPlaces ? communityPlaces.length : defaultNumberOfCommunityPlaces
                ) ) }
                { communityPlaces.length > defaultNumberOfCommunityPlaces && (
                  showAllPlaces ? (
                    <button className="btn btn-link btn-more" type="button" onClick={( ) => this.setState( { showAllPlaces: false } )}>
                      { I18n.t( "less" ) }
                    </button>
                  ) : (
                    <button className="btn btn-link btn-more" type="button" onClick={( ) => this.setState( { showAllPlaces: true } )}>
                      { I18n.t( "more" ) }
                    </button>
                  )
                ) }
              </div>
            ) }
          </div>
        </div>
        { observation.obscured && (
          observation.geoprivacy
          || observation.taxon_geoprivacy
        ) && (
          <div className="obscured">
            <h4>{ I18n.t( "why_the_coordinates_are_obscured" ) }</h4>
            <ul className="plain">
              { observation.geoprivacy === "obscured" && obscurationExplanationGeoprivacy }
              { observation.geoprivacy === "private" && (
                <li>
                  <strong>
                    <i className="icon-icn-location-private" />
                    { I18n.t( "label_colon", { label: I18n.t( "geoprivacy_is_private" ) } ) }
                  </strong>
                  { " " }
                  { I18n.t( "geoprivacy_is_private_desc" ) }
                </li>
              ) }
              { observation.taxon_geoprivacy === "obscured" && (
                <li>
                  <strong>
                    <i className="fa fa-flag" />
                    { I18n.t( "label_colon", { label: I18n.t( "taxon_is_threatened_coordinates_obscured" ) } ) }
                  </strong>
                  { " " }
                  { I18n.t( "taxon_is_threatened_coordinates_obscured_desc" ) }
                </li>
              ) }
              { observation.taxon_geoprivacy === "private" && (
                <li>
                  <strong>
                    <i className="fa fa-flag" />
                    { I18n.t( "label_colon", { label: I18n.t( "taxon_is_threatened_coordinates_hidden" ) } ) }
                  </strong>
                  { " " }
                  { I18n.t( "taxon_is_threatened_coordinates_hidden_desc" ) }
                </li>
              ) }
            </ul>
            <h4>{ I18n.t( "who_can_see_the_coordinates" ) }</h4>
            <ul className="plain">
              <li>
                <i className="icon-person" />
                { I18n.t( "who_can_see_the_coordinates_observer" ) }
              </li>
              <li>
                <i className="icon-people" />
                { I18n.t( "who_can_see_the_coordinates_trusted" ) }
              </li>
              { projectsWithCoordinateAccess
                && projectsWithCoordinateAccess.length > 0 && (
                <li>
                  <i className="fa fa-briefcase" />
                  { I18n.t( "label_colon", { label: I18n.t( "who_can_see_the_coordinates_projects" ) } ) }
                  <ul>
                    { projectsWithCoordinateAccess.map( project => (
                      <li key={`map-details-projects-${project.id}`}>
                        <a href={`/projects/${project.slug}`}>
                          { project.title }
                        </a>
                      </li>
                    ) ) }
                  </ul>
                </li>
              ) }
            </ul>
            { observation.private_geojson && (
              <div>
                <h4>{ I18n.t( "why_you_can_see_the_coordinates" ) }</h4>
                <ul className="plain">
                  { currentUser && observation.user && currentUser.id === observation.user.id && (
                    <li>
                      <strong>
                        <i className="icon-person" />
                        { I18n.t( "label_colon", { label: I18n.t( "this_is_your_observation" ) } ) }
                      </strong>
                      { " " }
                      { I18n.t( "this_is_your_observation_desc" ) }
                    </li>
                  ) }
                  { currentUserHasProjectCuratorCoordinateAccess && (
                    <li>
                      <strong>
                        <i className="fa fa-briefcase" />
                        { I18n.t( "label_colon", { label: I18n.t( "you_curate_a_project_that_contains_this_observation" ) } ) }
                      </strong>
                      { " " }
                      { I18n.t( "you_curate_a_project_that_contains_this_observation_desc" ) }
                    </li>
                  ) }
                  { observation.viewer_trusted_by_observer && (
                    <li>
                      <strong>
                        <i className="icon-person" />
                        { I18n.t( "label_colon", {
                          label: I18n.t( "user_trusts_you_with_their_private_coordinates", { user: observation.user.login } )
                        } ) }
                      </strong>
                      { " " }
                      { I18n.t( "user_trusts_you_with_their_private_coordinates_desc" ) }
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
                href={`https://www.google.com/maps?q=${observation.latitude},${observation.longitude}`}
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
              Nice to have, but sort of useless unless macrostrat implements the
              abililty to link to the infowindow and not just the coords
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
  config: PropTypes.object,
};

MapDetails.defaultProps = {
  config: {},
  observationPlaces: []
};

export default MapDetails;
