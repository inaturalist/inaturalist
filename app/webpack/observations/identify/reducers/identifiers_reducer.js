import {
  FETCH_IDENTIFIERS,
  RECEIVE_IDENTIFIERS
} from "../actions";

const identifiersReducer = ( state = { users: [], loading: false }, action ) => {
  if ( action.type === FETCH_IDENTIFIERS ) {
    return {
      loading: true,
      users: []
    };
  } else if ( action.type === RECEIVE_IDENTIFIERS ) {
    return {
      loading: false,
      users: action.users.slice( 0, 10 )
    };
  }
  return state;
};

export default identifiersReducer;
