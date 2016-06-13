import inatjs from "inaturalistjs";
import { paramsForSearch } from "../reducers/search_params_reducer";

const RECEIVE_IDENTIFIERS = "receive_identifiers";
const UPDATE_IDENTIFIERS = "update_identifiers";
const FETCH_IDENTIFIERS = "fetch_identifiers";

function receiveIdentifiers( response ) {
  return {
    type: RECEIVE_IDENTIFIERS,
    users: response.results
  };
}

function updateIdentifiers( updates ) {
  return {
    type: UPDATE_IDENTIFIERS,
    updates
  };
}

function fetchIdentifiers( ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const apiParams = Object.assign( { }, paramsForSearch( s.searchParams.params ), {
      reviewed: "any",
      quality_grade: "any"
    } );
    dispatch( updateIdentifiers( { loading: true } ) );
    return inatjs.observations.identifiers( apiParams )
      .then( response => dispatch( receiveIdentifiers( response ) ) );
  };
}

export {
  RECEIVE_IDENTIFIERS,
  UPDATE_IDENTIFIERS,
  FETCH_IDENTIFIERS,
  receiveIdentifiers,
  updateIdentifiers,
  fetchIdentifiers
};
