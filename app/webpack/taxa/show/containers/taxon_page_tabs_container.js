import { connect } from "react-redux";
import TaxonPageTabs from "../components/taxon_page_tabs";
import { fetchDescription, fetchLinks, fetchNames } from "../ducks/taxon";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchArticlesContent: ( ) => {
      dispatch( fetchDescription( ) );
      dispatch( fetchLinks( ) );
    },
    fetchNames: ( ) => dispatch( fetchNames( ) )
  };
}

const TaxonPageTabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonPageTabs );

export default TaxonPageTabsContainer;
