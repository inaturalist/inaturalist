import { connect } from "react-redux";
import ProjectForm from "../components/project_form";
import { setAttributes, addProjectRule, removeProjectRule,
  submitProject, updateProject, setRulePreference } from "../form_reducer";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.form.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setAttributes: attrs => dispatch( setAttributes( attrs ) ),
    addProjectRule: ( operator, operandType, operand ) =>
      dispatch( addProjectRule( operator, operandType, operand ) ),
    removeProjectRule: ( operator, operandType, operand ) =>
      dispatch( removeProjectRule( operator, operandType, operand ) ),
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
