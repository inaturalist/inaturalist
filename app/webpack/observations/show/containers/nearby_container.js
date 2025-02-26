import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";
import { showNewObservation } from "../ducks/observation";
import { fetchNearby } from "../ducks/other_observations";

function mapStateToProps( state ) {
  return {
    title: I18n.t( "nearby_observations_" ),
    observations: state.otherObservations.nearby?.observations,
    searchParams: state.otherObservations.nearby?.params,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation, options ) => {
      dispatch( showNewObservation( observation, options ) );
    },
    contentLoader: ( ) => {
      dispatch( fetchNearby( ) );
    }
  };
}

const NearbyContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsHighlight );

export default NearbyContainer;
