import { connect } from "react-redux";
import TaxonPageTabs from "../components/taxon_page_tabs";
import {
  fetchDescription,
  fetchLinks,
  fetchNames,
  fetchTrending,
  fetchRare,
  fetchSimilar,
  fetchInteractions
} from "../ducks/taxon";
import { fetchGlobiInteractions, fetchInatInteractions } from "../ducks/interactions";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    currentUser: state.config.currentUser
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchArticlesContent: ( ) => {
      dispatch( fetchDescription( ) );
      dispatch( fetchLinks( ) );
    },
    fetchNames: ( ) => dispatch( fetchNames( ) ),
    fetchInteractions: taxon => {
      dispatch( fetchInatInteractions( taxon ) );
      dispatch( fetchInteractions( ) );
    },
    fetchTrendingTaxa: ( ) => dispatch( fetchTrending( ) ),
    fetchRareTaxa: ( ) => dispatch( fetchRare( ) ),
    fetchSimilarTaxa: ( ) => dispatch( fetchSimilar( ) )
  };
}

const TaxonPageTabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonPageTabs );

export default TaxonPageTabsContainer;
