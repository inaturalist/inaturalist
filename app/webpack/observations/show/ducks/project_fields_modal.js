const SET_PROJECT_FIELDS_MODAL_STATE =
  "obs-show/project_fields_model/SET_PROJECT_FIELDS_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_PROJECT_FIELDS_MODAL_STATE:
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setProjectFieldsModalState( newState ) {
  return {
    type: SET_PROJECT_FIELDS_MODAL_STATE,
    newState
  };
}
