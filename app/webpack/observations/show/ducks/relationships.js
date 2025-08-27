import inatjs from "inaturalistjs";

const SET_RELATIONSHIPS = "obs-show/relationships/SET_RELATIONSHIPS";
const RESET_RELATIONSHIPS = "obs-show/relationships/RESET_RELATIONSHIPS";

export default function reducer( state = {
  relationships: [],
  loaded: false
}, action ) {
  switch ( action.type ) {
    case SET_RELATIONSHIPS:
      state.relationships = action.relationships;
      state.loaded = true;
      break;
    case RESET_RELATIONSHIPS:
      state.relationships = [];
      state.loaded = false;
      break;
    default:
      // Do nothing
  }
  return state;
}

export function setRelationships( relationships ) {
  return {
    type: SET_RELATIONSHIPS,
    relationships
  };
}

export function resetRelationships( ) {
  return { type: RESET_RELATIONSHIPS };
}

export function fetchRelationships( options = {} ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const observation = options.observation || s.observation;
    if ( !observation ) { return null; }
    const { testingApiV2 } = s.config;
    if ( !testingApiV2 ) {
      return null;
    }

    return inatjs.relationships.search( {
      user_id: observation.user.id
    } ).then( response => {
      dispatch( setRelationships( response.results ) );
    } ).catch( e => { } );
  };
}
