import { connect } from "react-redux";
import SpeciesTab from "../components/species_tab";
import { fetchSpecies, infiniteScrollSpecies } from "../ducks/project";

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
    fetchSpecies: ( ) => { dispatch( fetchSpecies( ) ); },
    infiniteScrollSpecies: nextScrollIndex => {
      dispatch( infiniteScrollSpecies( nextScrollIndex ) );
    }
  };
}

const SpeciesTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SpeciesTab );

export default SpeciesTabContainer;
