import { connect } from "react-redux";
import DisagreementAlert from "../components/disagreement_alert";
import {
  hideDisagreementAlert
} from "../ducks/disagreement_alert";

function mapStateToProps( state ) {
  return state.disagreementAlert;
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideDisagreementAlert( ) );
    }
  };
}

const AlertModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DisagreementAlert );

export default AlertModalContainer;
