import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";
import { showNewObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    title: I18n.t( "nearby_observations_" ),
    observations: state.otherObservations.nearby.observations,
    searchParams: state.otherObservations.nearby.params
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation, options ) => {
      dispatch( showNewObservation( observation, options ) );
    }
  };
}

const NearbyContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsHighlight );

export default NearbyContainer;
