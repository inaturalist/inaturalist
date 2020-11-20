const SHOW_MODAL = "revoke_access_modal/SHOW_MODAL";
const HIDE_MODAL = "revoke_access_modal/HIDE_MODAL";

export default function reducer( state = { show: false, id: null, siteName: null }, action ) {
  switch ( action.type ) {
    case SHOW_MODAL:
      return {
        ...state,
        show: true,
        id: action.id,
        siteName: action.siteName
      };
    case HIDE_MODAL:
      return {
        ...state,
        show: false,
        id: null,
        siteName: null
      };
    default:
  }
  return state;
}

export function showModal( id, siteName ) {
  return {
    type: SHOW_MODAL,
    id,
    siteName
  };
}

export function hideModal( ) {
  return { type: HIDE_MODAL };
}
