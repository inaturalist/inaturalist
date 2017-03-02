import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown } from "react-bootstrap";
import TaxonMap from "../../identify/components/taxon_map";
import MapDetails from "./map_details";

const Map = ( { observation, observationPlaces, config, setConfig } ) => {
  let taxonMap;
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
    if ( observation.place_guess.length > showLength &&
         !( config.map && config.map.expandLocation === true ) ) {
      placeGuess = `${observation.place_guess.substring( 0, showLength ).trim( )}...`;
      showMore = (
        <div className="show-more">
          <div onClick={ ( ) => { setConfig( { map: { expandLocation: true } } ); } }>Show</div>
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
              Details
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
};

Map.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  observationPlaces: PropTypes.array,
  setConfig: PropTypes.func
};

export default Map;
