import { connect } from "react-redux";
import Projects from "../components/projects";
import { } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return { };
}

const ProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Projects );

export default ProjectsContainer;
