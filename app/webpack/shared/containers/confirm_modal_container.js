import { connect } from "react-redux";
import ConfirmModal from "../components/confirm_modal";
import { updateConfirmModalState } from "../ducks/confirm_modal";

function mapStateToProps( state ) {
  return state.confirmModal;
}

function mapDispatchToProps( dispatch ) {
  return {
    updateConfirmModalState: updatedState => dispatch( updateConfirmModalState( updatedState ) )
  };
}

const ConfirmModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ConfirmModal );

export default ConfirmModalContainer;
