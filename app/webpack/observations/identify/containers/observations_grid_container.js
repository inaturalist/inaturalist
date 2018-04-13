import { connect } from "react-redux";
import ObservationsGrid from "../components/observations_grid";
import {
  showCurrentObservation,
  fetchCurrentObservation,
  toggleReviewed,
  agreeWithObservaiton
} from "../actions";

function mapStateToProps( state ) {
  return {
    observations: state.observations.results || [],
    currentUser: state.config.currentUser
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onObservationClick: ( observation ) => {
      dispatch( showCurrentObservation( observation ) );
      dispatch( fetchCurrentObservation( observation ) );
    },
    toggleReviewed: ( observation ) => {
      dispatch( toggleReviewed( observation ) );
    },
    onAgree: ( observation ) => {
      dispatch( agreeWithObservaiton( observation ) );
    }
  };
}

const ObservationsGridContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsGrid );

export default ObservationsGridContainer;
