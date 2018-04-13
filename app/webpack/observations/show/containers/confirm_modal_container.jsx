import { connect } from "react-redux";
import ConfirmModal from "../components/confirm_modal";
import { setConfirmModalState } from "../ducks/confirm_modal";

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
