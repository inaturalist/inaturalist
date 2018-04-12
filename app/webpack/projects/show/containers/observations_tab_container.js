import { connect } from "react-redux";
import ObservationsTab from "../components/observations_tab";
import { setConfig } from "../../../shared/ducks/config";
import {
  infiniteScrollObservations,
  setSelectedTab,
  setObservationFilters
} from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setObservationFilters: params => dispatch( setObservationFilters( params ) ),
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
