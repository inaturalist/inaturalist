import { connect } from "react-redux";
import { updateSession } from "../../../shared/util";
import { setConfig } from "../../../shared/ducks/config";
import TaxonPageTabs from "../components/taxon_page_tabs";
import {
  fetchDescription,
  fetchLinks,
  fetchNames,
  fetchInteractions,
  fetchTrending,
  fetchSimilar,
  showPhotoChooser
} from "../../shared/ducks/taxon";
import { getChosenTab } from "../../shared/util";


function mapStateToProps( state ) {
  const chosenTab= getChosenTab(state.config.chosenTab, state.taxon.taxon.rank_level);

  return {
    taxon: state.taxon.taxon,
    currentUser: state.config.currentUser,
    chosenTab
  };
}

function mapDispatchToProps( dispatch ) {
  const loadDataForTab = tab => {
    switch ( tab ) {
      case "articles":
        dispatch( fetchDescription( ) );
        dispatch( fetchLinks( ) );
        break;
      case "taxonomy":
        dispatch( fetchNames( ) );
        break;
      case "interactions":
        dispatch( fetchInteractions( ) );
        break;
      case "highlights":
        dispatch( fetchTrending( ) );
        break;
      case "similar":
        dispatch( fetchSimilar( ) );
        break;
      default:
        // it's cool, you probably have what you need
    }
  };
  return {
    showPhotoChooserModal: ( ) => dispatch( showPhotoChooser( ) ),
    choseTab: tab => {
      location.hash = `#${tab}-tab`;
      dispatch( setConfig( { chosenTab: tab } ) );
      loadDataForTab( tab );
      updateSession( { preferred_taxon_page_tab: tab } );
    },
    loadDataForTab
  };
}

const TaxonPageTabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonPageTabs );

export default TaxonPageTabsContainer;
