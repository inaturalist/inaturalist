const SHOW_ALERT = "show_alert";
const HIDE_ALERT = "hide_alert";

export default function alertReducer( state = { visible: false }, action ) {
  if ( action.type === SHOW_ALERT ) {
    return { visible: true, content: action.content, ...action.options };
  }
  if ( action.type === HIDE_ALERT ) {
    return { ...state, visible: false };
  }
  return state;
}

export function showAlert( content, options = {} ) {
  return { type: SHOW_ALERT, content, options };
}

export function hideAlert( ) { return { type: HIDE_ALERT }; }
