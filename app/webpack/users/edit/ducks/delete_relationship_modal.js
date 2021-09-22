const SHOW_MODAL = "delete_relationship_modal/SHOW_MODAL";
const HIDE_MODAL = "delete_relationship_modal/HIDE_MODAL";

export default function reducer( state = { show: false, user: null }, action ) {
  switch ( action.type ) {
    case SHOW_MODAL:
      return { ...state, show: true, user: action.user };
    case HIDE_MODAL:
      return { ...state, show: false, user: null };
    default:
  }
  return state;
}

export function showModal( user ) {
  return {
    type: SHOW_MODAL,
    user
  };
}

export function hideModal( ) {
  return { type: HIDE_MODAL };
}
