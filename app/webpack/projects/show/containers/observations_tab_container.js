import { connect } from "react-redux";
import ObservationsTab from "../components/observations_tab";
import { setConfig } from "../../../shared/ducks/config";
import { infiniteScrollObservations } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    observations: state.project && state.project.observations_loaded ?
      state.project.observations.results : null
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    infiniteScrollObservations: nextScrollIndex => {
      dispatch( infiniteScrollObservations( nextScrollIndex ) );
    }
  };
}

const ObservationsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsTab );

export default ObservationsTabContainer;
