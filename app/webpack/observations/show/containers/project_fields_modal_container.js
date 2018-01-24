import { connect } from "react-redux";
import ProjectFieldsModal from "../components/project_fields_modal";
import { addObservationFieldValue,
  updateObservationFieldValue } from "../ducks/observation";
import { setProjectFieldsModalState } from "../ducks/project_fields_modal";

function mapStateToProps( state ) {
  return Object.assign( { }, state.projectFieldsModal, {
    observation: state.observation,
    config: state.config
  } );
}

function mapDispatchToProps( dispatch ) {
  return {
    addObservationFieldValue: options => { dispatch( addObservationFieldValue( options ) ); },
    updateObservationFieldValue: ( id, options ) => {
      dispatch( updateObservationFieldValue( id, options ) );
    },
    setProjectFieldsModalState: ( key, value ) => {
      dispatch( setProjectFieldsModalState( key, value ) );
    }
  };
}

const ProjectFieldsModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ProjectFieldsModal );

export default ProjectFieldsModalContainer;
