import { connect } from "react-redux";
import ArticlesTab from "../components/articles_tab";
import ArticlesTabLegacy from "../components/articles_tab_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    description: state.taxon.description ? state.taxon.description.body : null,
    descriptionSource: state.taxon.description ? state.taxon.description.source : null,
    descriptionSourceUrl: state.taxon.description ? state.taxon.description.url : null,
    links: state.taxon.links,
    currentUser: state.config.currentUser
  };
}

const ArticlesTabContainer = connect(
  mapStateToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, ArticlesTab, ArticlesTabLegacy ) );

export default ArticlesTabContainer;
