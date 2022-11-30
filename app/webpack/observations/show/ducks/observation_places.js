import inatjs from "inaturalistjs";

const SET_OBSERVATION_PLACES = "obs-show/observation_places/SET_OBSERVATION_PLACES";

const FIELDS = {
  admin_level: true,
  bbox_area: true,
  display_name: true,
  id: true,
  name: true,
  place_type: true,
  uuid: true
};

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_OBSERVATION_PLACES:
      return action.places;
    default:
      // nothing to see here
  }
  return state;
}

export function setObservationPlaces( places ) {
  return {
    type: SET_OBSERVATION_PLACES,
    places
  };
}

export function fetchObservationPlaces( ) {
  return ( dispatch, getState ) => {
    const { observation, config } = getState( );
    const { testingApiV2 } = config;
    if ( !observation || !observation.latitude || !observation.longitude ) {
      return null;
    }
    const params = {
      lat: observation.latitude,
      lng: observation.longitude,
      no_geom: true,
      order_by: "admin_and_distance"
    };
    if ( testingApiV2 ) {
      params.fields = FIELDS;
    }
    let placeIDs;
    if ( observation.private_place_ids && observation.private_place_ids.length > 0 ) {
      placeIDs = observation.private_place_ids;
    } else {
      placeIDs = observation.place_ids;
    }
    if ( !placeIDs || placeIDs.length === 0 ) {
      return null;
    }
    return inatjs.places.fetch( placeIDs, params ).then( response => {
      dispatch( setObservationPlaces( response.results ) );
    } ).catch( ( ) => { } );
  };
}
