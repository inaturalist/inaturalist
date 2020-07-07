import { connect } from "react-redux";
import ProjectForm from "../components/project_form";
import {
  setAttributes,
  addProjectRule,
  removeProjectRule,
  addManager,
  removeProjectManager,
  changeOwner,
  setDescription,
  setTitle,
  confirmSubmitProject,
  updateProject,
  onFileDrop,
  deleteProject,
  setRulePreference,
  removeProject,
  duplicateProject
} from "../form_reducer";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.form.project,
    allControlledTerms: state.controlledTerms.allTerms
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setAttributes: attrs => dispatch( setAttributes( attrs ) ),
    onFileDrop: ( droppedFiles, field ) => dispatch( onFileDrop( droppedFiles, field ) ),
    addProjectRule: ( operator, operandType, operand ) => dispatch(
      addProjectRule( operator, operandType, operand )
    ),
    removeProjectRule: ( operator, operandType, operand ) => dispatch(
      removeProjectRule( operator, operandType, operand )
    ),
    addManager: user => dispatch( addManager( user ) ),
    removeProjectManager: user => dispatch( removeProjectManager( user ) ),
    setDescription: description => dispatch( setDescription( description ) ),
    setTitle: title => dispatch( setTitle( title ) ),
    removeProject: ( ) => dispatch( removeProject( ) ),
    confirmSubmitProject: ( ) => dispatch( confirmSubmitProject( ) ),
    updateProject: attrs => dispatch( updateProject( attrs ) ),
    deleteProject: ( ) => dispatch( deleteProject( ) ),
    duplicateProject: ( ) => dispatch( duplicateProject( ) ),
    setRulePreference: ( field, value ) => dispatch( setRulePreference( field, value ) ),
    changeOwner: projectUser => dispatch( changeOwner( projectUser ) )
  };
}

const ProjectFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ProjectForm );

export default ProjectFormContainer;
