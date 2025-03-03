import { connect } from "react-redux";
import ObservationsGrid from "../components/observations_grid";
import {
  showCurrentObservation,
  fetchCurrentObservation,
  toggleReviewed,
  agreeWithObservaiton
} from "../actions";
import { confirmResendConfirmation } from "../../../shared/ducks/user_confirmation";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observations: state.observations.results || [],
    currentUser: state.config.currentUser,
    imageSize: state.config.imageSize,
    confirmationEmailSent: state.confirmation.confirmationEmailSent
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onObservationClick: observation => {
      dispatch( showCurrentObservation( observation ) );
      dispatch( fetchCurrentObservation( observation ) );
    },
    toggleReviewed: observation => {
      dispatch( toggleReviewed( observation ) );
    },
    onAgree: observation => {
      dispatch( agreeWithObservaiton( observation ) );
    },
    confirmResendConfirmation: method => dispatch( confirmResendConfirmation( method ) )
  };
}

const ObservationsGridContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsGrid );

export default ObservationsGridContainer;
