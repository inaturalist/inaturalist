const SET_API_RESPONSE = "notifications-demo/SET_API_RESPONSE";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_API_RESPONSE:
      return action.apiResponse;
    default:
  }
  return state;
}

export function setAPIResponse( apiResponse ) {
  return {
    type: SET_API_RESPONSE,
    apiResponse
  };
}

export function initialize( apiResponse, callback ) {
  return dispatch => {
    dispatch( setAPIResponse( apiResponse ) );
    setTimeout( callback, 10 );
  };
}
