import { connect } from "react-redux";
import ObservationsGrid from "../components/observations_grid";
import { showCurrentObservation } from "../actions";

function mapStateToProps( state ) {
  if ( !state.observations ) {
    return { observations: [] };
  }
  return {
    observations: state.observations
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onObservationClick: ( observation ) => {
      dispatch( showCurrentObservation( observation ) );
    }
  };
}

const ObservationsGridContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsGrid );

export default ObservationsGridContainer;
