import _ from "lodash";
import React, { PropTypes } from "react";
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
    // fieldIDs used by projects
    const projectFieldIDs = _.compact( _.flatten( observation.project_observations.map( po => (
      ( po.project.project_observation_fields || [] ).map( pof => (
        pof.observation_field.id ) ) ) ) ) );
    let nonProjectFieldValues = observation.ofvs;
    if ( projectFieldIDs.length > 0 ) {
      // remove any project fields from this presentation
      nonProjectFieldValues = _.filter( observation.ofvs, ofv => ( (
        !_.includes( projectFieldIDs, ofv.field_id )
      ) ) );
    }
    if ( _.isEmpty( nonProjectFieldValues ) && !loggedIn ) { return ( <span /> ); }
    const sortedFieldValues = _.sortBy( nonProjectFieldValues, ofv => (
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
      <div className="ObservationFields">
        <h4
          className="collapsable"
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
        <Panel collapsible expanded={ this.state.open }>
          { panelContent }
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
