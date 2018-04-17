import { connect } from "react-redux";
import ConfirmModal from "../../../observations/show/components/confirm_modal";
import { setConfirmModalState } from "../../../observations/show/ducks/confirm_modal";

function mapStateToProps( state ) {
  return state.confirmModal;
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfirmModalState: ( key, value ) => { dispatch( setConfirmModalState( key, value ) ); }
  };
}

const ConfirmModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ConfirmModal );

export default ConfirmModalContainer;
