import { connect } from "react-redux";
import AlertModal from "../components/alert_modal";
import { hideAlert } from "../ducks/alert_modal";

function mapStateToProps( state ) {
  return state.alertModal;
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => dispatch( hideAlert( ) )
  };
}

const AlertModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( AlertModal );

export default AlertModalContainer;
