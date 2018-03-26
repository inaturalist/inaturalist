import { connect } from "react-redux";
import ProjectForm from "../components/project_form";
import {
  setAttributes,
  addProjectRule,
  removeProjectRule,
  addManager,
  removeProjectUser,
  setTitle,
  submitProject,
  updateProject,
  onFileDrop,
  setRulePreference } from "../form_reducer";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.form.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setAttributes: attrs => dispatch( setAttributes( attrs ) ),
    onFileDrop: ( droppedFiles, field ) => dispatch( onFileDrop( droppedFiles, field ) ),
    addProjectRule: ( operator, operandType, operand ) =>
      dispatch( addProjectRule( operator, operandType, operand ) ),
    removeProjectRule: ( operator, operandType, operand ) =>
      dispatch( removeProjectRule( operator, operandType, operand ) ),
    addManager: user => dispatch( addManager( user ) ),
    removeProjectUser: user => dispatch( removeProjectUser( user ) ),
    setTitle: title => dispatch( setTitle( title ) ),
    submitProject: ( ) => dispatch( submitProject( ) ),
    updateProject: attrs => dispatch( updateProject( attrs ) ),
    setRulePreference: ( field, value ) => dispatch( setRulePreference( field, value ) )
  };
}

const ProjectFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ProjectForm );

export default ProjectFormContainer;
