import { connect } from "react-redux";
import ConfirmModal from "../components/confirm_modal";
import { updateConfirmEmailModalState } from "../ducks/confirm_email_modal";

function mapStateToProps( state ) {
  return state.confirmEmailModal;
}

function mapDispatchToProps( dispatch ) {
  return {
    updateConfirmModalState: updatedState => dispatch(
      updateConfirmEmailModalState( updatedState )
    )
  };
}

const ConfirmEmailModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ConfirmModal );

export default ConfirmEmailModalContainer;
