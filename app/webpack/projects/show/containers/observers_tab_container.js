import { connect } from "react-redux";
import ObserversTab from "../components/observers_tab";
import { setObserversSort, fetchObservers } from "../ducks/project";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observers: state.config.observersSort === "species" && state.project.species_observers_loaded
      ? state.project.species_observers && state.project.species_observers.results
      : state.project.observers && state.project.observers.results,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    setObserversSort: attributes => { dispatch( setObserversSort( attributes ) ); },
    fetchObservers: ( ) => { dispatch( fetchObservers( true ) ); }
  };
}

const ObserversTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObserversTab );

export default ObserversTabContainer;
