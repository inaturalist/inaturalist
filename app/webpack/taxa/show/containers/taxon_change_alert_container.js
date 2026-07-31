import { connect } from "react-redux";
import TaxonChangeAlert from "../components/taxon_change_alert";
import TaxonChangeAlertLegacy from "../components/taxon_change_alert_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    taxonChange: state.taxon.taxonChange
  };
}

function mapDispatchToProps( ) {
  return { };
}

const TaxonChangeAlertContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, TaxonChangeAlert, TaxonChangeAlertLegacy ) );

export default TaxonChangeAlertContainer;
