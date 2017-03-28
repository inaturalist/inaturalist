import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";
import { showNewObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    title: "Observations of relatives",
    observations: state.otherObservations.moreFromClade.observations,
    searchParams: state.otherObservations.moreFromClade.params
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation ) => { dispatch( showNewObservation( observation ) ); }
  };
}

const SimilarContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsHighlight );

export default SimilarContainer;
