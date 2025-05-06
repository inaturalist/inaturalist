import { connect } from "react-redux";
import FavoriteProjects from "../components/favorite_projects";
import { fetchFavoriteProjects } from "../ducks/favorite_projects";
import {
  addFavoriteProject,
  NO_CHANGE,
  saveUserSettings,
  updateUserData
} from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    config: state.config,
    favoriteProjects: state.favoriteProjects,
    user: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  // For both of these callbacks, we update the user locally, then update only
  // that attribute remotely, to match the behavior of TaxonNamePriorities,
  // which also update the content without needing to press the save button.
  // Similar, we use skipFetch to avoid overriding any other local changes.
  return {
    addProject: project => {
      dispatch( addFavoriteProject( project ) );
      dispatch( saveUserSettings( { only: ["faved_project_ids"], skipFetch: true } ) );
    },
    updateFavedProjectIds: projectIds => {
      dispatch( updateUserData( { faved_project_ids: projectIds }, { savedStatus: NO_CHANGE } ) );
      dispatch( saveUserSettings( { only: ["faved_project_ids"], skipFetch: true } ) );
      dispatch( fetchFavoriteProjects( ) );
    }
  };
}

const FavoriteProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FavoriteProjects );

export default FavoriteProjectsContainer;
