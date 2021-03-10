import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import {
  OverlayTrigger,
  Tooltip,
  Modal,
  Button
} from "react-bootstrap";
import ObservationFieldInput from "./observation_field_input";

class ProjectFieldsModal extends Component {
  constructor( ) {
    super( );
    this.close = this.close.bind( this );
    this.submit = this.submit.bind( this );
  }

  close( ) {
    this.props.setProjectFieldsModalState( { show: false, alreadyInProject: false } );
  }

  submit( ) {
    if ( _.isFunction( this.props.onSubmit ) ) {
      this.props.onSubmit( );
    }
    this.close( );
  }

  render( ) {
    const {
      observation,
      project,
      alreadyInProject,
      config,
      updateObservationFieldValue,
      addObservationFieldValue,
      show
    } = this.props;
    if ( !project || !observation || _.isEmpty( project.project_observation_fields ) ) {
      return ( <div /> );
    }
    let requiredFieldsPopulated = true;
    const fieldList = _.map( _.sortBy( project.project_observation_fields, "position" ), pf => {
      const existingFieldValue = _.find( observation.ofvs,
        ofv => ofv.observation_field.id === pf.observation_field.id );
      if ( pf.required && !existingFieldValue ) {
        requiredFieldsPopulated = false;
      }
      return (
        <div
          className={`field ${pf.required && !existingFieldValue ? "required-missing" : null}`}
          key={`proj-fields-form-${pf.id}`}
        >
          <ObservationFieldInput
            observationField={pf.observation_field}
            required={pf.required}
            observationFieldValue={existingFieldValue ? existingFieldValue.value : null}
            observationFieldTaxon={existingFieldValue ? existingFieldValue.taxon : null}
            key={`projects-field-${pf.observation_field.id}`}
            hideFieldChooser
            noCancel
            noReset
            editing={!!existingFieldValue}
            originalOfv={existingFieldValue}
            onSubmit={r => {
              if ( existingFieldValue ) {
                if ( r.value !== existingFieldValue.value ) {
                  updateObservationFieldValue( existingFieldValue.uuid, r );
                }
              } else {
                addObservationFieldValue( r );
              }
            }}
            config={config}
          />
        </div>
      );
    } );
    let submit = (
      <Button
        bsStyle="success"
        onClick={requiredFieldsPopulated ? this.submit : null}
        className={!requiredFieldsPopulated ? "disabled" : ""}
      >
        { I18n.t( "add_to_project" ) }
      </Button>
    );
    if ( !requiredFieldsPopulated ) {
      submit = (
        <OverlayTrigger
          placement="top"
          delayShow={20}
          overlay={(
            <Tooltip id="missing-required">
              { I18n.t( "you_must_fill_out_the_required_fields" ) }
            </Tooltip>
          )}
          key="missing-required-overlay"
        >
          { submit }
        </OverlayTrigger>
      );
    }
    return (
      <Modal
        show={show}
        className="ProjectFieldsModal"
        onHide={this.close}
        backdrop="static"
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { project.title }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          { alreadyInProject ? null : (
            <div className="intro">
              { I18n.t( "please_complete_the_following_to_add_project" ) }
            </div>
          ) }
          <div className="text">
            { fieldList }
          </div>
          { alreadyInProject ? null : (
            <span className="required">
              *
              { " " }
              { I18n.t( "required_" ) }
            </span>
          ) }
        </Modal.Body>
        { alreadyInProject ? null : (
          <Modal.Footer>
            <div className="buttons">
              <Button bsStyle="default" onClick={this.close}>
                { I18n.t( "cancel" ) }
              </Button>
              { submit }
            </div>
          </Modal.Footer>
        ) }
      </Modal>
    );
  }
}

ProjectFieldsModal.propTypes = {
  addObservationFieldValue: PropTypes.func,
  updateObservationFieldValue: PropTypes.func,
  observation: PropTypes.object,
  onSubmit: PropTypes.func,
  project: PropTypes.object,
  setProjectFieldsModalState: PropTypes.func,
  show: PropTypes.bool,
  alreadyInProject: PropTypes.bool,
  config: PropTypes.object
};

export default ProjectFieldsModal;
