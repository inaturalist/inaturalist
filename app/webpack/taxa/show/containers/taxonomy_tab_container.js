import { connect } from "react-redux";
import TaxonomyTab from "../components/taxonomy_tab";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    taxonChangesCount: state.taxon.counts.taxonChangesCount,
    taxonSchemesCount: state.taxon.counts.taxonSchemesCount
  };
}

const TaxonomyTabContainer = connect(
  mapStateToProps
)( TaxonomyTab );

export default TaxonomyTabContainer;
