import { connect } from "react-redux";
import TaxonomyTab from "../components/taxonomy_tab";
import { showNewTaxon } from "../actions/taxon";
import { toggleConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    taxonChangesCount: state.taxon.counts.taxonChangesCount,
    taxonSchemesCount: state.taxon.counts.taxonSchemesCount,
    names: state.taxon.names,
    allChildrenShown: state.config.allChildrenShown
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: ( taxon, options ) => dispatch( showNewTaxon( taxon, options ) ),
    toggleAllChildrenShown: ( ) => dispatch( toggleConfig( "allChildrenShown" ) )
  };
}

const TaxonomyTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonomyTab );

export default TaxonomyTabContainer;
