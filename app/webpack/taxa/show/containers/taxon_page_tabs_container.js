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

function mapStateToProps( state ) {
  const speciesTabs = ["map", "articles", "interactions", "taxonomy", "status", "similar"];
  const genusTabs = ["map", "articles", "highlights", "taxonomy", "similar"];
  const aboveGenusTabs = ["map", "articles", "highlights", "taxonomy"];
  let chosenTab;
  if (
    ( state.taxon.taxon.rank_level <= 10 && speciesTabs.indexOf( state.config.chosenTab ) >= 0 )
    || ( state.taxon.taxon.rank_level === 20 && genusTabs.indexOf( state.config.chosenTab ) >= 0 )
    || (
      state.taxon.taxon.rank_level > 20
      && aboveGenusTabs.indexOf( state.config.chosenTab ) >= 0
    )
  ) {
    ( { chosenTab } = state.config );
  }
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
