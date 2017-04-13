import _ from "lodash";
import React, { PropTypes } from "react";
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
        <div className="no_location">
          <i className="fa fa-map-marker" />
          { I18n.t( "location_unknown" ) }
        </div>
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
        "geoprivacy",
        "taxon",
        "user"
      ] );
      obsForMap.coordinates_obscured = observation.obscured;
      taxonMap = (
        <TaxonMap
          key={`map-for-${observation.id}`}
          taxonLayers={[{
            taxon: obsForMap.taxon,
            observations: { observation_id: obsForMap.id },
            places: { disabled: true },
            gbif: { disabled: true }
          }] }
          static
          observations={[obsForMap]}
          zoomLevel={ observation.map_scale || 8 }
          mapTypeControl={false}
          showAccuracy
          showAllLayer={false}
          scrollwheel={false}
          overlayMenu
          clickable={false}
          zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
        />
      );
    }
    let placeGuessElement;
    let placeGuess = observation.place_guess;
    if ( placeGuess ) {
      let showMore;
      const obscured = observation.obscured && ( <span className="obscured">(Obscured)</span> );
      const showLength = observation.obscured ? 22 : 32;
      if ( observation.place_guess.length > showLength && !this.state.showLongLabel ) {
        placeGuess = `${observation.place_guess.substring( 0, showLength ).trim( )}...`;
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
    return (
      <div className="Map">
        { taxonMap }
        <div className="map_details">
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
