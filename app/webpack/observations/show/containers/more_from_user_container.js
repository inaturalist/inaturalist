import { connect } from "react-redux";
import MoreFromUser from "../components/more_from_user";
import MoreFromUserLegacy from "../components/more_from_user_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { showNewObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    otherObservations: state.otherObservations,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation, options ) => {
      dispatch( showNewObservation( observation, options ) );
    }
  };
}

const MoreFromUserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, MoreFromUser, MoreFromUserLegacy ) );

export default MoreFromUserContainer;
