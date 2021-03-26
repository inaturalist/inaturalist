import { connect } from "react-redux";
import ObserversTab from "../components/observers_tab";
import { setConfig } from "../../../shared/ducks/config";
import { fetchSpeciesObservers } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observers: state.config.observersSort === "species" ?
      state.project.species_observers && state.project.species_observers.results :
      state.project.observers && state.project.observers.results
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    fetchSpeciesObservers: ( ) => dispatch( fetchSpeciesObservers( ) )
  };
}

const ObserversTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ObserversTab );

export default ObserversTabContainer;
