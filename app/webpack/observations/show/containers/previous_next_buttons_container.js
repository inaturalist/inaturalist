import { connect } from "react-redux";
import PreviousNextButtons from "../components/previous_next_buttons";
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

const PreviousNextButtonsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PreviousNextButtons );

export default PreviousNextButtonsContainer;
