import { connect } from "react-redux";
import ObservationsGrid from "../components/observations_grid";
import { showCurrentObservation } from "../actions";
import Observation from "../models/observation";

function mapStateToProps( state ) {
  if ( !state.observations ) {
    return { observations: [] };
  }
  return {
    observations: state.observations.map( o => {
      const no = new Observation( o );
      return no;
    } )
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
