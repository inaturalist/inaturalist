import _ from "lodash";
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
    const currentUserInIdentifiers = _.find(
      s.identifiers.users, u => u.user_id === s.config.currentUser.id
    );
    if ( s.identifiers.users.length > 0 && !currentUserInIdentifiers ) {
      // If the current user isn't in the list of identifiers, there's no reason
      // to update that list with every new identification
      return Promise.resolve( );
    }
    const apiParams = Object.assign( { }, paramsForSearch( s.searchParams.params ), {
      reviewed: "any",
      quality_grade: "any",
      page: 1,
      per_page: 10,
      order: "",
      order_by: ""
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
