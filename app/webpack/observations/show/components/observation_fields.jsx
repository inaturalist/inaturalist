import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Panel } from "react-bootstrap";
import ObservationFieldValue from "./observation_field_value";
import ObservationFieldInput from "./observation_field_input";

class ObservationFields extends React.Component {

  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_observation_fields : true,
      editingFieldValue: null
    };
  }

  render( ) {
    const { observation, config, placeholder } = this.props;
    const loggedIn = config && config.currentUser;
    if ( !observation || !observation.user || ( _.isEmpty( observation.ofvs ) && !loggedIn ) ) {
      return ( <span /> );
    }
    const sortedFieldValues = _.sortBy( observation.ofvs, ofv => (
      `${ofv.value ? "a" : "z"}:${ofv.name}:${ofv.value}`
    ) );
    let addValueInput;
    if ( loggedIn ) {
      addValueInput = (
        <div className="form-group">
          <ObservationFieldInput
            notIDs={ _.compact( _.uniq( _.map( observation.ofvs, ofv => (
              ofv.observation_field && ofv.observation_field.id ) ) ) ) }
            onSubmit={ r => {
              this.props.addObservationFieldValue( r );
            } }
            placeholder={ placeholder }
            config={ config }
          />
        </div>
      );
    }
    const panelContent = (
      <div>
        { sortedFieldValues.map( ofv => {
          if ( this.state.editingFieldValue && this.state.editingFieldValue.uuid === ofv.uuid ) {
            return (
              <ObservationFieldInput
                observationField={ ofv.observation_field }
                observationFieldValue={ ofv.value }
                observationFieldTaxon={ ofv.taxon }
                key={ `editing-field-value-${ofv.uuid}` }
                setEditingFieldValue={ fieldValue => {
                  this.setState( { editingFieldValue: fieldValue } );
                }}
                editing
                originalOfv={ ofv }
                hideFieldChooser
                onCancel={ ( ) => {
                  this.setState( { editingFieldValue: null } );
                } }
                onSubmit={ r => {
                  if ( r.value !== ofv.value ) {
                    this.props.updateObservationFieldValue( ofv.uuid, r );
                  }
                  this.setState( { editingFieldValue: null } );
                } }
              />
            );
          }
          return (
            <ObservationFieldValue
              ofv={ ofv }
              key={ `field-value-${ofv.uuid || ofv.observation_field.id}` }
              setEditingFieldValue={ fieldValue => {
                this.setState( { editingFieldValue: fieldValue } );
              }}
              { ...this.props }
            />
          );
        } ) }
        { addValueInput }
      </div>
    );

    if ( !this.props.collapsible ) {
      return (
        <div className="ObservationFields">
          { panelContent }
        </div>
      );
    }

    const count = sortedFieldValues.length > 0 ? `(${sortedFieldValues.length})` : "";
    return (
      <div className="ObservationFields collapsible-section">
        <h4
          className="collapsible"
          onClick={ ( ) => {
            if ( loggedIn ) {
              this.props.updateSession( {
                prefers_hide_obs_show_observation_fields: this.state.open } );
            }
            this.setState( { open: !this.state.open } );
          } }
        >
          <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
          { I18n.t( "observation_fields" ) } { count }
        </h4>
        <Panel expanded={ this.state.open } onToggle={ () => {} }>
          <Panel.Collapse>{ panelContent }</Panel.Collapse>
        </Panel>
      </div>
    );
  }
}

ObservationFields.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  addObservationFieldValue: PropTypes.func,
  removeObservationFieldValue: PropTypes.func,
  updateObservationFieldValue: PropTypes.func,
  updateSession: PropTypes.func,
  collapsible: PropTypes.bool,
  placeholder: PropTypes.string
};

ObservationFields.defaultProps = {
  collapsible: true
};

export default ObservationFields;
