import { connect } from "react-redux";
import FavoriteProjects from "../components/favorite_projects";

function mapStateToProps( state ) {
  return {
    config: state.config,
    favoriteProjects: state.favoriteProjects
  };
}

function mapDispatchToProps( ) {
  return {};
}

const FavoriteProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FavoriteProjects );

export default FavoriteProjectsContainer;
