import { connect } from "react-redux";
import Map from "../components/map";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.observation,
    observationPlaces: state.observationPlaces
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: ( config ) => { dispatch( setConfig( config ) ); },
    unfave: ( config ) => { dispatch( setConfig( config ) ); }
  };
}

const MapContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Map );

export default MapContainer;
