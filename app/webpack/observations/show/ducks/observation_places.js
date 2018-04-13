import inatjs from "inaturalistjs";

const SET_OBSERVATION_PLACES = "obs-show/observation_places/SET_OBSERVATION_PLACES";

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
    const observation = getState( ).observation;
    if ( !observation || !observation.latitude || !observation.longitude ) {
      return null;
    }
    const params = { lat: observation.latitude, lng: observation.longitude,
      no_geom: true, order_by: "admin_and_distance" };
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
    } ).catch( e => { } );
  };
}
