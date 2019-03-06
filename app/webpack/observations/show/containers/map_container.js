import { connect } from "react-redux";
import { updateCurrentUser } from "../../../shared/ducks/config";
import Map from "../components/map";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observationPlaces: state.observationPlaces,
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
