import { connect } from "react-redux";
import SpeciesComparison from "../components/species_comparison";
import { sortFrequenciesByIndex, setTaxonFilter } from "../ducks/compare";

function mapStateToProps( state ) {
  return {
    queries: state.compare.queries,
    taxa: state.compare.taxa,
    taxonFrequencies: state.compare.taxonFrequencies,
    taxonFrequenciesSortIndex: state.compare.taxonFrequenciesSortIndex,
    taxonFrequenciesSortOrder: state.compare.taxonFrequenciesSortOrder,
    numTaxaDistinct: state.compare.numTaxaDistinct,
    numTaxaInCommon: state.compare.numTaxaInCommon,
    taxonFilter: state.compare.taxonFilter
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    sortFrequenciesByIndex: ( index, order ) => dispatch( sortFrequenciesByIndex( index, order ) ),
    setTaxonFilter: filter => dispatch( setTaxonFilter( filter ) )
  };
}

const SpeciesComparisonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SpeciesComparison );

export default SpeciesComparisonContainer;
