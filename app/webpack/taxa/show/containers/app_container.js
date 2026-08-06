import { connect } from "react-redux";
import App from "../components/app";
import AppLegacy from "../components/app_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { showNewTaxon } from "../actions/taxon";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, App, AppLegacy ) );

export default AppContainer;

