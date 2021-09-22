const SET_EXPORT_MODAL_STATE = "lifelists-show/export_modal/SET_EXPORT_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_EXPORT_MODAL_STATE:
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setExportModalState( newState ) {
  return {
    type: SET_EXPORT_MODAL_STATE,
    newState
  };
}
