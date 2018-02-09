import { connect } from "react-redux";
import DisagreementAlert from "../../shared/components/disagreement_alert";
import {
  hideDisagreementAlert
} from "../../shared/ducks/disagreement_alert";

function mapStateToProps( state ) {
  return Object.assign( { config: state.config }, state.disagreementAlert );
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => {
      dispatch( hideDisagreementAlert( ) );
    }
  };
}

const DisagreementAlertContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DisagreementAlert );

export default DisagreementAlertContainer;
