import { connect } from "react-redux";
import TaxonPageTabs from "../components/taxon_page_tabs";
import {
  fetchDescription,
  fetchLinks,
  fetchNames,
  fetchInteractions,
  fetchTrending,
  fetchRare,
  fetchSimilar,
  showPhotoChooser
} from "../../shared/ducks/taxon";

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
    fetchInteractions: ( ) => dispatch( fetchInteractions( ) ),
    fetchTrendingTaxa: ( ) => dispatch( fetchTrending( ) ),
    fetchRareTaxa: ( ) => dispatch( fetchRare( ) ),
    fetchSimilarTaxa: ( ) => dispatch( fetchSimilar( ) ),
    showPhotoChooserModal: ( ) => dispatch( showPhotoChooser( ) )
  };
}

const TaxonPageTabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonPageTabs );

export default TaxonPageTabsContainer;
