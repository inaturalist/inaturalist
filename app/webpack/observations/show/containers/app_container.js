import { connect } from "react-redux";
import App from "../components/app";
import { leaveTestGroup } from "../ducks/users";
import { deleteObservation } from "../ducks/observation";
import { setLicensingModalState } from "../ducks/licensing_modal";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    controlledTerms: state.controlledTerms.terms
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    leaveTestGroup: group => { dispatch( leaveTestGroup( group ) ); },
    deleteObservation: ( ) => { dispatch( deleteObservation( ) ); },
    setLicensingModalState: ( key, value ) => {
      dispatch( setLicensingModalState( key, value ) );
    }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
