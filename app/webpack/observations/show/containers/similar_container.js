import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";

function mapStateToProps( state ) {
  return {
    title: "Observations of relatives",
    observations: state.otherObservations.moreFromClade.observations,
    searchParams: state.otherObservations.moreFromClade.params
  };
}

const SimilarContainer = connect(
  mapStateToProps
)( ObservationsHighlight );

export default SimilarContainer;
