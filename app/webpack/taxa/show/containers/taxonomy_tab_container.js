import { connect } from "react-redux";
import TaxonomyTab from "../components/taxonomy_tab";
import TaxonomyTabLegacy from "../components/taxonomy_tab_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { showNewTaxon } from "../actions/taxon";
import { toggleConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    taxonChangesCount: state.taxon.counts.taxonChangesCount,
    taxonSchemesCount: state.taxon.counts.taxonSchemesCount,
    names: state.taxon.names,
    allChildrenShown: state.config.allChildrenShown,
    provisionalChildrenShown: state.config.provisionalChildrenShown,
    currentUser: state.config.currentUser,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: ( taxon, options ) => dispatch( showNewTaxon( taxon, options ) ),
    toggleAllChildrenShown: ( ) => dispatch( toggleConfig( "allChildrenShown" ) ),
    toggleProvisionalChildrenShown: ( ) => dispatch( toggleConfig( "provisionalChildrenShown" ) )
  };
}

const TaxonomyTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, TaxonomyTab, TaxonomyTabLegacy ) );

export default TaxonomyTabContainer;
