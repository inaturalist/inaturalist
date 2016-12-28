import { connect } from "react-redux";
import ArticlesTab from "../components/articles_tab";

function mapStateToProps( state ) {
  return {
    taxonId: state.taxon.taxon.id,
    description: state.taxon.description ? state.taxon.description.body : null,
    descriptionSource: state.taxon.description ? state.taxon.description.source : null,
    descriptionSourceUrl: state.taxon.description ? state.taxon.description.url : null,
    links: state.taxon.links,
    currentUser: state.config.currentUser
  };
}

const ArticlesTabContainer = connect(
  mapStateToProps
)( ArticlesTab );

export default ArticlesTabContainer;
