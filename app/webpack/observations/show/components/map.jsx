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
        zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
      />
    );
  }
  let placeGuess;
  if ( observation.place_guess.length > 22 &&
       !( config.map && config.map.expandLocation === true ) ) {
    placeGuess = (
      <div>
        <span>{ observation.place_guess.substring( 0, 22 ).trim( ) }...</span>
        <div className="show-more">
          <div onClick={ ( ) => { setConfig( { map: { expandLocation: true } } ); } }>Show </div>
          (Obscured)</div>
      </div>
    );
  } else {
    placeGuess = observation.place_guess;
  }
  return (
    <div className="Map">
      { taxonMap }
      <div className="map_details">
        <div className="place-guess">
          { placeGuess }
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
