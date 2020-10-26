// const SET_MODAL = "revoke_access_modal/SET_MODAL";
const SHOW_MODAL = "revoke_access_modal/SHOW_MODAL";
const HIDE_MODAL = "revoke_access_modal/HIDE_MODAL";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    // case SET_MODAL:
    //   return { ...action.application };
    //   break;
    case SHOW_MODAL:
      return { ...state, show: true };
    case HIDE_MODAL:
      return { ...state, show: false };
    default:
  }
  return state;
}

// export function setModal( ) {
//   return {
//     type: SET_MODAL,
//     application
//   };
// }

export function showModal( ) {
  return { type: SHOW_MODAL };
}

export function hideModal( ) {
  return { type: HIDE_MODAL };
}
