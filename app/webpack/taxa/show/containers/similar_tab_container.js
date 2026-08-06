import { connect } from "react-redux";
import SimilarTab from "../components/similar_tab";
import SimilarTabLegacy from "../components/similar_tab_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { showNewTaxon } from "../actions/taxon";

function mapStateToProps( state ) {
  return {
    results: state.taxon.similar,
    place: state.config.chosenPlace,
    config: state.config,
    taxon: state.taxon.taxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) )
  };
}

const SimilarTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, SimilarTab, SimilarTabLegacy ) );

export default SimilarTabContainer;
