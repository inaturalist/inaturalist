const SHOW_MODAL = "observations-compare/taxon_children_modal/SHOW_MODAL";
const HIDE_MODAL = "observations-compare/taxon_children_modal/HIDE_MODAL";

export default function reducer( state = { visible: false }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SHOW_MODAL:
      newState.visible = true;
      break;
    case HIDE_MODAL:
      newState.visible = false;
      break;
    default:
      // ok
  }
  return newState;
}

export function showModal( ) {
  return { type: SHOW_MODAL };
}

export function hideModal( ) {
  return { type: HIDE_MODAL };
}
