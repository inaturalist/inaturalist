import { connect } from "react-redux";
import SpeciesTab from "../components/species_tab";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    species: state.project && state.project.species_loaded ?
      state.project.species.results : null
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); }
  };
}

const SpeciesTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SpeciesTab );

export default SpeciesTabContainer;
