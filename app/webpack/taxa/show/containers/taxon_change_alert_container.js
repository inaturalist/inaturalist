import { connect } from "react-redux";
import TaxonChangeAlert from "../components/taxon_change_alert";

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
)( TaxonChangeAlert );

export default TaxonChangeAlertContainer;
