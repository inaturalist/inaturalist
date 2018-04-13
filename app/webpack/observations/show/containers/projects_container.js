import { connect } from "react-redux";
import Projects from "../components/projects";
import { addToProject, confirmRemoveFromProject,
  updateObservationFieldValue, removeObservationFieldValue } from "../ducks/observation";
import { joinProject } from "../ducks/projects";
import { updateCuratorAccess } from "../ducks/project_observations";
import { updateSession } from "../ducks/users";
import { setProjectFieldsModalState } from "../ducks/project_fields_modal";

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
    removeObservationFieldValue: id => { dispatch( removeObservationFieldValue( id ) ); },
    updateCuratorAccess: ( po, value ) => { dispatch( updateCuratorAccess( po, value ) ); },
    updateObservationFieldValue: ( id, options ) => {
      dispatch( updateObservationFieldValue( id, options ) );
    },
    updateSession: params => { dispatch( updateSession( params ) ); },
    showProjectFieldsModal: project => {
      dispatch( setProjectFieldsModalState( {
        show: true,
        alreadyInProject: true,
        project
      } ) );
    }
  };
}

const ProjectsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Projects );

export default ProjectsContainer;
