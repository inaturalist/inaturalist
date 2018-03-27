import { connect } from "react-redux";
import ObservationsTab from "../components/observations_tab";
import { setConfig } from "../../../shared/ducks/config";
import { infiniteScrollObservations, setSelectedTab } from "../ducks/project";

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
    setSelectedTab: ( tab, options ) => dispatch( setSelectedTab( tab, options ) ),
    setObservationsSearchSubview: subview =>
      dispatch( setConfig( { observationsSearchSubview: subview } ) ),
    infiniteScrollObservations: nextScrollIndex =>
      dispatch( infiniteScrollObservations( nextScrollIndex ) )
  };
}

const ObservationsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObservationsTab );

export default ObservationsTabContainer;
