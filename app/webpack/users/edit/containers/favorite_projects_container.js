import { connect } from "react-redux";
import FavoriteProjects from "../components/favorite_projects";
import { addFavoriteProject, updateUserData } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    config: state.config,
    favoriteProjects: state.favoriteProjects,
    user: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addProject: project => dispatch( addFavoriteProject( project ) ),
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
