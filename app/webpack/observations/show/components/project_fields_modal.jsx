import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { OverlayTrigger, Tooltip } from "react-bootstrap";
import { Modal, Button } from "react-bootstrap";
import ObservationFieldInput from "./observation_field_input";

class ProjectFieldsModal extends Component {

  constructor( ) {
    super( );
    this.close = this.close.bind( this );
    this.submit = this.submit.bind( this );
  }

  close( ) {
    this.props.setProjectFieldsModalState( { show: false } );
  }

  submit( ) {
    if ( _.isFunction( this.props.onSubmit ) ) {
      this.props.onSubmit( );
    }
    this.close( );
  }

  render( ) {
    const { observation, project } = this.props;
    if ( !project || !observation || _.isEmpty( project.project_observation_fields ) ) {
      return ( <div /> );
    }
    let requiredFieldsPopulated = true;
    const fieldList = _.map( _.sortBy( project.project_observation_fields, "position" ), pf => {
      const existingFieldValue = _.find( observation.ofvs, ofv =>
        ofv.observation_field.id === pf.observation_field.id );
      if ( pf.required && !existingFieldValue ) {
        requiredFieldsPopulated = false;
      }
      return (
        <div
          className={ `field ${pf.required && !existingFieldValue ? "required-missing" : null}` }
          key={ `proj-fields-form-${pf.id}` }
        >
          <ObservationFieldInput
            observationField={ pf.observation_field }
            required={ pf.required }
            observationFieldValue={ existingFieldValue ? existingFieldValue.value : null }
            observationFieldTaxon={ existingFieldValue ? existingFieldValue.taxon : null }
            key={ `projects-field-${pf.observation_field.id}` }
            hideFieldChooser
            noCancel
            noReset
            editing={ !!existingFieldValue }
            originalOfv={ existingFieldValue }
            onSubmit={ r => {
              if ( existingFieldValue ) {
                if ( r.value !== existingFieldValue.value ) {
                  this.props.updateObservationFieldValue( existingFieldValue.uuid, r );
                }
              } else {
                this.props.addObservationFieldValue( r );
              }
            } }
          />
        </div>
       );
    } );
    let submit = (
      <Button
        bsStyle="success"
        onClick={ requiredFieldsPopulated ? this.submit : null }
        className={ !requiredFieldsPopulated ? "disabled" : "" }
      >
        { I18n.t( "add_to_project" ) }
      </Button>
    );
    if ( !requiredFieldsPopulated ) {
      submit = (
        <OverlayTrigger
          placement="top"
          delayShow={ 20 }
          overlay={ (
            <Tooltip id="missing-required">
              You must fill out the required fields
            </Tooltip> ) }
          key="missing-required-overlay"
        >
          { submit }
        </OverlayTrigger>
      );
    }
    return (
      <Modal
        show={ this.props.show }
        className="ProjectFieldsModal"
        onHide={ this.close }
        backdrop="static"
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { project.title }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="intro">
            Please complete the following to add this observation to the project:
          </div>
          <div className="text">
            { fieldList }
          </div>
          <span className="required">
            * Required
          </span>
        </Modal.Body>
        <Modal.Footer>
          <div className="buttons">
            <Button bsStyle="default" onClick={ this.close }>
              { I18n.t( "cancel" ) }
            </Button>
            { submit }
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

ProjectFieldsModal.propTypes = {
  addObservationFieldValue: PropTypes.func,
  updateObservationFieldValue: PropTypes.func,
  missingRequiredFields: PropTypes.array,
  observation: PropTypes.object,
  onSubmit: PropTypes.func,
  project: PropTypes.object,
  setProjectFieldsModalState: PropTypes.func,
  show: PropTypes.bool
};

export default ProjectFieldsModal;
