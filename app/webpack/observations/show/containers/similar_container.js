import { connect } from "react-redux";
import ObservationsHighlight from "../components/observations_highlight";
import { showNewObservation } from "../ducks/observation";
import { fetchMoreFromClade } from "../ducks/other_observations";

function mapStateToProps( state ) {
  return {
    title: I18n.t( "observations_of_relatives" ),
    observations: state.otherObservations.moreFromClade?.observations,
    searchParams: state.otherObservations.moreFromClade?.params,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewObservation: ( observation, options ) => {
      dispatch( showNewObservation( observation, options ) );
    },
    contentLoader: ( ) => {
      dispatch( fetchMoreFromClade( ) );
    }
  };
}

const SimilarContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsHighlight );

export default SimilarContainer;
