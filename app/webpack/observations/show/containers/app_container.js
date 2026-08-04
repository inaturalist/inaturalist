import { connect } from "react-redux";
import App from "../components/app";
import AppLegacy from "../components/app_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { leaveTestGroup } from "../ducks/users";
import { deleteObservation } from "../ducks/observation";
import { setLicensingModalState } from "../ducks/licensing_modal";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
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
)( gatedComponent( RESPONSIVE_TEST_GROUPS, App, AppLegacy ) );

export default AppContainer;
