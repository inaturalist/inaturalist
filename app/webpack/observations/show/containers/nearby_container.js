import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";

function mapStateToProps( state ) {
  return {
    title: "Nearby observations",
    observations: state.otherObservations.nearby.observations,
    searchParams: state.otherObservations.nearby.params
  };
}

const NearbyContainer = connect(
  mapStateToProps
)( ObservationsHighlight );

export default NearbyContainer;
