import inatjs from "inaturalistjs";

const SET_OBSERVATION_LINKS = "obs-show/observation_links/SET_OBSERVATION_LINKS";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_OBSERVATION_LINKS:
      return action.links;
    default:
  }
  return state;
}

export function setObservationLinks( links ) {
  return {
    type: SET_OBSERVATION_LINKS,
    links
  };
}

export function fetchObservationLinks( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation ) { return; }
    const params = { id: observation.id };
    inatjs.observations.observationLinks( params ).then( response => {
      dispatch( setObservationLinks( response ) );
    } );
  };
}
