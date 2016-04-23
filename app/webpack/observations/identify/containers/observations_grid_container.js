import { connect } from "react-redux";
import ObservationsGrid from "../components/observations_grid";
import { showCurrentObservation, fetchCurrentObservation } from "../actions";

function mapStateToProps( state ) {
  return {
    observations: state.observations.results || []
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onObservationClick: ( observation ) => {
      dispatch( showCurrentObservation( observation ) );
      dispatch( fetchCurrentObservation( observation ) );
    }
  };
}

const ObservationsGridContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsGrid );

export default ObservationsGridContainer;
