import { connect } from "react-redux";
import { updateCurrentUser } from "../../../shared/ducks/config";
import Map from "../components/map";
import { updateObservation } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observationPlaces: state.observationPlaces,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
    disableAutoObscuration: ( ) => {
      if ( confirm( "Are you sure? This might allow people to guess the coordinates of some threatened species you observed." ) ) {
        dispatch( updateObservation( { prefers_auto_obscuration: false } ) );
      }
    },
    restoreAutoObscuration: ( ) => {
      dispatch( updateObservation( { prefers_auto_obscuration: true } ) );
    }
  };
}

const MapContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Map );

export default MapContainer;
