import { connect } from "react-redux";
import TaxonomyTab from "../components/taxonomy_tab";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    taxonChangesCount: state.taxon.counts.taxonChangesCount,
    taxonSchemesCount: state.taxon.counts.taxonSchemesCount,
    names: state.taxon.names
  };
}

const TaxonomyTabContainer = connect(
  mapStateToProps
)( TaxonomyTab );

export default TaxonomyTabContainer;
