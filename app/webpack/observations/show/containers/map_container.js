import { connect } from "react-redux";
import Map from "../components/map";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observationPlaces: state.observationPlaces,
    config: state.config
  };
}

const MapContainer = connect(
  mapStateToProps
)( Map );

export default MapContainer;
