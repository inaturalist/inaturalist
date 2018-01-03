const SHOW_DISAGREEMENT_ALERT = "show_disagreement_alert";
const HIDE_DISAGREEMENT_ALERT = "hide_disagreement_alert";

const disagreementAlertReducer = ( state = { visible: false }, action ) => {
  if ( action.type === SHOW_DISAGREEMENT_ALERT ) {
    return Object.assign( { visible: true }, action.options );
  } else if ( action.type === HIDE_DISAGREEMENT_ALERT ) {
    return Object.assign( {}, state, { visible: false } );
  }
  return state;
};

const showDisagreementAlert = ( options = {} ) => ( { type: SHOW_DISAGREEMENT_ALERT, options } );
const hideDisagreementAlert = ( ) => ( { type: HIDE_DISAGREEMENT_ALERT } );

export default disagreementAlertReducer;
export {
  SHOW_DISAGREEMENT_ALERT,
  HIDE_DISAGREEMENT_ALERT,
  showDisagreementAlert,
  hideDisagreementAlert
};
