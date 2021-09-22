import inatjs from "inaturalistjs";

const SET_IDENTIFIERS = "obs-show/identifications/SET_IDENTIFIERS";
const SET_LAST_FETCH_TIME = "obs-show/identifications/SET_LAST_FETCH_TIME";

export default function reducer( state = {
  identifiers: null,
  lastFetchTime: null
}, action ) {
  switch ( action.type ) {
    case SET_IDENTIFIERS:
      return Object.assign( { }, state, { identifiers: action.identifiers } );
    case SET_LAST_FETCH_TIME:
      return Object.assign( { }, state, { lastFetchTime: action.lastFetchTime } );
    default:
  }
  return state;
}

export function setIdentifiers( identifiers ) {
  return {
    type: SET_IDENTIFIERS,
    identifiers
  };
}

export function setLastFetchTime( lastFetchTime ) {
  return {
    type: SET_LAST_FETCH_TIME,
    lastFetchTime
  };
}

export function fetchIdentifiers( params ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const { testingApiV2 } = state.config;
    const time = Date.now( );
    dispatch( setLastFetchTime( time ) );
    const identifiersParams = Object.assign(
      { },
      params,
      testingApiV2
        ? {
          fields: {
            count: true,
            user: {
              login: true,
              icon_url: true
            }
          }
        }
        : {}
    );
    inatjs.identifications.identifiers( identifiersParams ).then( response => {
      // fetch the state again since we're reset lastFetchTime
      const { identifications } = getState( );
      if ( time === identifications.lastFetchTime ) {
        dispatch( setIdentifiers( response.results ) );
      }
    } ).catch( ( ) => { } );
  };
}
