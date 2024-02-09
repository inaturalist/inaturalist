import _ from "lodash";
import React from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";
import { Dropdown } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon, taxonLayerForTaxon } from "../../../taxa/shared/util";
import TaxonMap from "../../identify/components/taxon_map";
import MapDetails from "./map_details";
import ErrorBoundary from "../../../shared/components/error_boundary";

/* global LIFE_TAXON */

class Map extends React.Component {
  constructor( ) {
    super( );
    this.state = { showLongLabel: false };
  }

  render( ) {
    let taxonMap;
    const {
      observation,
      observationPlaces,
      config,
      updateCurrentUser
    } = this.props;
    let geoprivacyIconClass = "fa fa-map-marker";
    let geoprivacyTitle = I18n.t( "location_is_public" );
    let geoprivacyLabel = I18n.t( "location_unknown" );
    // Note this is based on the currently confusing nature of obscured, which
    // at present means coordinates_obscured? OR geoprivacy == "obscured", so if
    // there are no coordinates and geoprivacy is obscured, we set the
    // geoprivacy icon and title, but the location is legitimately unknown. If
    // there are no coordinates and the geoprivacy is private, then
    // observation.obscured will be false
    if (
      observation.obscured
      && (
        observation.geoprivacy
        || observation.taxon_geoprivacy
      )
    ) {
      if (
        observation.geoprivacy === "private"
        || observation.taxon_geoprivacy === "private"
      ) {
        geoprivacyIconClass = "icon-icn-location-private";
        geoprivacyTitle = I18n.t( "location_is_private" );
        geoprivacyLabel = I18n.t( "location_private" );
      } else {
        geoprivacyIconClass = "icon-icn-location-obscured";
        geoprivacyTitle = I18n.t( "location_is_obscured" );
      }
    } else if ( !observation.latitude && !observation.private_geojson ) {
      geoprivacyIconClass = "icon-no-location";
      geoprivacyLabel = I18n.t( "location_unknown" );
    }
    let placeGuess = I18n.t( "location_unknown" );
    if ( observation ) {
      if ( !observation.private_geojson && observation.geoprivacy === "private" ) {
        placeGuess = I18n.t( "private_" );
      } else {
        placeGuess = observation.private_place_guess || observation.place_guess;
      }
    }
    if ( !observation || !observation.latitude ) {
      return (
        <div className="Map">
          <div className="TaxonMap empty">
            <div className="no_location">
              <i className="fa fa-map-marker" />
              { geoprivacyLabel }
            </div>
          </div>
          <div className="map_details">
            <i
              className={`geoprivacy-icon ${geoprivacyIconClass}`}
              title={geoprivacyTitle}
              alt={geoprivacyTitle}
            />
            <div className="place-guess">{ placeGuess }</div>
            <div className="details_menu">
              <Dropdown
                id="grouping-control"
              >
                <Dropdown.Toggle>
                  { I18n.t( "details" ) }
                </Dropdown.Toggle>
                <Dropdown.Menu className="dropdown-menu-right">
                  <li>
                    <MapDetails
                      observation={observation}
                      observationPlaces={observationPlaces}
                      config={config}
                    />
                  </li>
                </Dropdown.Menu>
              </Dropdown>
            </div>
          </div>
        </div>
      );
    }
    if ( observation.latitude ) {
      // Select a small set of attributes that won't change wildy as the
      // observation changes.
      const obsForMap = _.pick( observation, [
        "id",
        "species_guess",
        "latitude",
        "longitude",
        "positional_accuracy",
        "public_positional_accuracy",
        "geoprivacy",
        "user",
        "map_scale"
      ] );
      if ( observation.taxon && ( LIFE_TAXON && observation.taxon.id !== LIFE_TAXON.id ) ) {
        obsForMap.taxon = Object.assign( { }, observation.taxon, {
          forced_name: ReactDOMServer.renderToString(
            <SplitTaxon
              taxon={observation.taxon}
              user={config.currentUser}
              noParens
              iconLink
              url={urlForTaxon( observation.taxon )}
            />
          )
        } );
      }
      obsForMap.coordinates_obscured = observation.obscured && !observation.private_geojson;
      const mapKey = `map-for-${observation.id}-${observation.taxon ? observation.taxon.id : null}`;
      const taxonLayer = taxonLayerForTaxon( obsForMap.taxon, {
        currentUser: config.currentUser,
        updateCurrentUser,
        observation
      } );
      taxonLayer.places = false;
      taxonLayer.ranges = false;
      taxonMap = (
        <TaxonMap
          key={mapKey}
          placement="observations-show"
          reloadKey={mapKey}
          taxonLayers={[taxonLayer]}
          observations={[obsForMap]}
          zoomLevel={observation.map_scale || 8}
          showAccuracy
          enableShowAllLayer={false}
          overlayMenu
          clickable={false}
          zoomControlOptions={{
            position: typeof ( google ) !== "undefined" && (
              $( "html[dir='rtl']" ).length > 0
                ? google.maps.ControlPosition.TOP_RIGHT
                : google.maps.ControlPosition.TOP_LEFT
            )
          }}
          currentUser={config.currentUser}
          updateCurrentUser={updateCurrentUser}
        />
      );
    }
    let placeGuessElement;
    if ( placeGuess ) {
      let showMore;
      const obscured = observation.obscured && !observation.private_geojson
        && (
          <span className="obscured">
            { "(" }
            { I18n.t( "obscured" ) }
            { ")" }
          </span>
        );
      const showLength = observation.obscured ? 22 : 32;
      const { showLongLabel } = this.state;
      if ( placeGuess.length > showLength && !showLongLabel ) {
        placeGuess = `${placeGuess.substring( 0, showLength ).trim( )}...`;
        showMore = (
          <div className="show-more">
            <button
              type="button"
              className="btn btn-nostyle"
              onClick={( ) => { this.setState( { showLongLabel: true } ); }}
            >
              { I18n.t( "show" ) }
            </button>
          </div> );
      }
      placeGuessElement = (
        <div>
          <span className="place">{ placeGuess }</span>
          { showMore }
          { obscured }
        </div>
      );
    }
    return (
      <div className="Map">
        { taxonMap }
        <div className="map_details">
          <i
            className={`geoprivacy-icon ${geoprivacyIconClass}`}
            title={geoprivacyTitle}
            alt={geoprivacyTitle}
          />
          <div className="place-guess">
            { placeGuessElement }
          </div>
          <div className="details_menu">
            <Dropdown
              id="grouping-control"
            >
              <Dropdown.Toggle>
                { I18n.t( "details" ) }
              </Dropdown.Toggle>
              <Dropdown.Menu className="dropdown-menu-right">
                <li>
                  <MapDetails
                    observation={observation}
                    observationPlaces={observationPlaces}
                    config={config}
                  />
                </li>
              </Dropdown.Menu>
            </Dropdown>
          </div>
        </div>
      </div>
    );
  }
}

Map.propTypes = {
  observation: PropTypes.object,
  observationPlaces: PropTypes.array,
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
};

export default Map;
