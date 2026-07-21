import { connect } from "react-redux";
import MoreFromUser from "../components/more_from_user";
import MoreFromUserLegacy from "../components/more_from_user_legacy";
import gatedComponent from "../components/gated_component";
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
)( gatedComponent( MoreFromUser, MoreFromUserLegacy ) );

export default MoreFromUserContainer;
