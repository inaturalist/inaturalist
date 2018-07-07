import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown } from "react-bootstrap";
import TaxonMap from "../../identify/components/taxon_map";
import MapDetails from "./map_details";

class Map extends React.Component {
  constructor( ) {
    super( );
    this.state = { showLongLabel: false };
  }

  render( ) {
    let taxonMap;
    const observation = this.props.observation;
    const observationPlaces = this.props.observationPlaces;
    if ( !observation || !observation.latitude ) {
      return ( <div className="Map">
        <div className="TaxonMap empty">
          <div className="no_location">
            <i className="fa fa-map-marker" />
            { observation.obscured && observation.geoprivacy === "private" ?
              I18n.t( "location_private" ) : I18n.t( "location_unknown" ) }
          </div>
        </div>
        <div className="map_details" />
      </div> );
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
        "taxon",
        "user",
        "map_scale"
      ] );
      obsForMap.coordinates_obscured = observation.obscured && !observation.private_geojson;
      const mapKey = `map-for-${observation.id}-${observation.taxon ? observation.taxon.id : null}`;
      taxonMap = (
        <TaxonMap
          key={ mapKey }
          reloadKey={ mapKey }
          taxonLayers={[{
            taxon: obsForMap.taxon,
            observations: { observation_id: obsForMap.id },
            places: { disabled: true },
            gbif: { disabled: true }
          }] }
          observations={[obsForMap]}
          zoomLevel={ observation.map_scale || 8 }
          showAccuracy
          enableShowAllLayer={false}
          overlayMenu
          clickable={false}
          zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
        />
      );
    }
    let placeGuessElement;
    let placeGuess = observation.private_place_guess || observation.place_guess;
    if ( placeGuess ) {
      let showMore;
      const obscured = observation.obscured && !observation.private_geojson &&
        ( <span className="obscured">({ I18n.t( "obscured" )})</span> );
      const showLength = observation.obscured ? 22 : 32;
      if ( placeGuess.length > showLength && !this.state.showLongLabel ) {
        placeGuess = `${placeGuess.substring( 0, showLength ).trim( )}...`;
        showMore = (
          <div className="show-more">
            <div onClick={ ( ) => { this.setState( { showLongLabel: true } ); } }>
              { I18n.t( "show" ) }
            </div>
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
    let geoprivacyIconClass = "fa fa-map-marker";
    let geoprivacyTitle = I18n.t( "location_is_public" );
    if ( observation.obscured && !observation.latitude && !observation.private_geojson ) {
      geoprivacyIconClass = "icon-no-location";
    } else if ( observation.geoprivacy === "private" ) {
      geoprivacyIconClass = "icon-icn-location-private";
      geoprivacyTitle = I18n.t( "location_is_private" );
    } else if ( observation.obscured ) {
      geoprivacyIconClass = "icon-icn-location-obscured";
      geoprivacyTitle = I18n.t( "location_is_obscured" );
    }
    return (
      <div className="Map">
        { taxonMap }
        <div className="map_details">
          <i
            className={ `geoprivacy-icon ${geoprivacyIconClass}` }
            title={ geoprivacyTitle }
            alt={ geoprivacyTitle }
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
                    observation={ observation }
                    observationPlaces={ observationPlaces }
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
  observationPlaces: PropTypes.array
};

export default Map;
