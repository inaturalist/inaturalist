const SHOW_MODAL = "revoke_access_modal/SHOW_MODAL";
const HIDE_MODAL = "revoke_access_modal/HIDE_MODAL";

export default function reducer( state = {
  show: false,
  siteName: null,
  official: null
}, action ) {
  switch ( action.type ) {
    case SHOW_MODAL:
      return {
        ...state,
        show: true,
        siteName: action.siteName,
        official: action.official
      };
    case HIDE_MODAL:
      return {
        ...state,
        show: false,
        siteName: null,
        official: null
      };
    default:
  }
  return state;
}

export function showModal( siteName, official ) {
  return {
    type: SHOW_MODAL,
    siteName,
    official
  };
}

export function hideModal( ) {
  return { type: HIDE_MODAL };
}
