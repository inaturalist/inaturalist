import { connect } from "react-redux";
import Annotations from "../../show/components/projects";
import {
  addToProject,
  confirmRemoveFromProject,
  joinProject,
  removeObservationFieldValue,
  updateObservationFieldValue
} from "../actions/current_observation_actions";
import { updateCuratorAccess } from "../../show/ducks/project_observations";
import { setProjectFieldsModalState } from "../../show/ducks/project_fields_modal";
import { updateSession } from "../../show/ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.currentObservation.observation,
    config: state.config,
    placeholder: I18n.t( "add_a_field" ),
    context: "identify"
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addToProject: project => { dispatch( addToProject( project ) ); },
    removeFromProject: project => { dispatch( confirmRemoveFromProject( project ) ); },
    joinProject: project => { dispatch( joinProject( project ) ); },
    removeObservationFieldValue: id => { dispatch( removeObservationFieldValue( id ) ); },
    updateCuratorAccess: ( po, value ) => { dispatch( updateCuratorAccess( po, value ) ); },
    updateObservationFieldValue: ( id, options ) => {
      dispatch( updateObservationFieldValue( id, options ) );
    },
    showProjectFieldsModal: project => {
      dispatch( setProjectFieldsModalState( {
        show: true,
        alreadyInProject: true,
        project
      } ) );
    },
    updateSession: params => { dispatch( updateSession( params ) ); }
  };
}

const AnnotationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Annotations );

export default AnnotationsContainer;
