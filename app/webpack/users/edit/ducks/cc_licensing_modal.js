const SHOW_MODAL = "about_licensing_modal/SHOW_MODAL";
const HIDE_MODAL = "about_licensing_modal/HIDE_MODAL";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SHOW_MODAL:
      return { ...state, show: true };
    case HIDE_MODAL:
      return { ...state, show: false };
    default:
  }
  return state;
}

export function showModal( ) {
  return {
    type: SHOW_MODAL
  };
}

export function hideModal( ) {
  return { type: HIDE_MODAL };
}
