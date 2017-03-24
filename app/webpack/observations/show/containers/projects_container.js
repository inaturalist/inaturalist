import { connect } from "react-redux";
import Projects from "../components/projects";
import { addToProject, confirmRemoveFromProject } from "../ducks/observation";
import { joinProject } from "../ducks/projects";
import { updateCuratorAccess } from "../ducks/project_observations";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addToProject: ( project ) => { dispatch( addToProject( project ) ); },
    removeFromProject: ( project ) => { dispatch( confirmRemoveFromProject( project ) ); },
    joinProject: ( project ) => { dispatch( joinProject( project ) ); },
    updateCuratorAccess: ( po, value ) => { dispatch( updateCuratorAccess( po, value ) ); }
  };
}

const ProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Projects );

export default ProjectsContainer;
