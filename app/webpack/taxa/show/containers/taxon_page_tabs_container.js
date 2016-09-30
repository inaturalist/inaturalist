import { connect } from "react-redux";
import TaxonPageTabs from "../components/taxon_page_tabs";
import { fetchDescription, fetchLinks } from "../ducks/taxon";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    description: state.taxon.description
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchArticlesContent: ( ) => {
      dispatch( fetchDescription( ) );
      dispatch( fetchLinks( ) );
    }
  };
}

const TaxonPageTabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonPageTabs );

export default TaxonPageTabsContainer;
