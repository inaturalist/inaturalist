import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";
import { showNewObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    title: "Nearby observations",
    observations: state.otherObservations.nearby.observations,
    searchParams: state.otherObservations.nearby.params
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation ) => { dispatch( showNewObservation( observation ) ); }
  };
}

const NearbyContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsHighlight );

export default NearbyContainer;
