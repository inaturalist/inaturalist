import { connect } from "react-redux";
import PreviousNextButtons from "../components/previous_next_buttons";
import { showNewObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    otherObservations: state.otherObservations
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation ) => { dispatch( showNewObservation( observation ) ); }
  };
}

const PreviousNextButtonsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PreviousNextButtons );

export default PreviousNextButtonsContainer;
