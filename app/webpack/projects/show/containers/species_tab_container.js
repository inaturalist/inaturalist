import { connect } from "react-redux";
import SpeciesTab from "../components/species_tab";
import { setConfig } from "../../../shared/ducks/config";
import { infiniteScrollSpecies } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    species: state.project && state.project.species_loaded
      ? state.project.species.results : null
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    infiniteScrollSpecies: ( previousScrollIndex, nextScrollIndex ) => dispatch(
      infiniteScrollSpecies( previousScrollIndex, nextScrollIndex )
    )
  };
}

const SpeciesTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SpeciesTab );

export default SpeciesTabContainer;
