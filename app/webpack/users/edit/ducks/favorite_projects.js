import inatjs from "inaturalistjs";

const SET_FAVORITE_PROJECTS = "user/edit/SET_FAVORITE_PROJECTS";

const PROJECT_FIELDS = "id,title,project_type";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_FAVORITE_PROJECTS:
      return action.projects;
    default:
  }
  return state;
}

export function setFavoriteProjects( projects ) {
  return {
    type: SET_FAVORITE_PROJECTS,
    projects
  };
}

export function fetchFavoriteProjects( userArg ) {
  return function ( dispatch, getState ) {
    const user = userArg || getState( ).profile;
    if ( !user.faved_project_ids || Number( user.faved_project_ids ) === 0 ) {
      return dispatch( setFavoriteProjects( [] ) );
    }

    return inatjs.projects.fetch( user.faved_project_ids, { fields: PROJECT_FIELDS } )
      .then( response => dispatch(
        setFavoriteProjects(
          // Ensure projects are in the correct order
          user.faved_project_ids.map(
            projectId => response.results.find( p => p.id === projectId )
          )
        )
      ) );
  };
}
