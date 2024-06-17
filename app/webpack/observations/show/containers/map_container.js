import { connect } from "react-redux";
import { updateCurrentUser } from "../../../shared/ducks/config";
import Map from "../components/map";

function coordinatesObscured( observation ) {
  return observation.latitude || observation.obscured;
}

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observationPlaces: state.observationPlaces,
    canInterpolate: (
      state.config
      && state.config.currentUser
      && state.config.currentUser.roles.indexOf( "admin" ) >= 0
      && state.observation
      && state.observation.user
      && state.config.currentUser.id === state.observation.user.id
      && state.observation.time_observed_at
      && state.otherObservations
      && state.otherObservations.earlierUserObservationsByObserved
      && state.otherObservations.laterUserObservationsByObserved
      && state
        .otherObservations
        .earlierUserObservationsByObserved
        .filter( coordinatesObscured )
        .length > 0
      && state
        .otherObservations
        .laterUserObservationsByObserved
        .filter( coordinatesObscured )
        .length > 0
    ),
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) )
  };
}

const MapContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Map );

export default MapContainer;
