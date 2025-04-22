import { connect } from "react-redux";
import FavoriteProjects from "../components/favorite_projects";
import { updateUserData } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    config: state.config,
    favoriteProjects: state.favoriteProjects
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateFavedProjectIds: projectIds => dispatch(
      updateUserData( { faved_project_ids: projectIds } )
    )
  };
}

const FavoriteProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FavoriteProjects );

export default FavoriteProjectsContainer;
