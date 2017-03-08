import { connect } from "react-redux";
import Projects from "../components/projects";
import { addToProject, removeFromProject } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addToProject: ( project ) => { dispatch( addToProject( project ) ); },
    removeFromProject: ( project ) => { dispatch( removeFromProject( project ) ); }
  };
}

const ProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Projects );

export default ProjectsContainer;
