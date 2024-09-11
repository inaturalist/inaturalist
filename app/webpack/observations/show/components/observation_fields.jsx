import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Panel } from "react-bootstrap";
import ObservationFieldValue from "./observation_field_value";
import ObservationFieldInput from "./observation_field_input";

class ObservationFields extends React.Component {
  constructor( props ) {
    super( props );
    const { config, observation, context } = props;
    this.observerPrefersFieldsBy = (
      observation.user
      && observation.user.preferences
      && observation.user.preferences.prefers_observation_fields_by
    )
      ? observation.user.preferences.prefers_observation_fields_by
      : "anyone";
    const currentUser = config && config.currentUser;
    this.collapsePreference = `prefers_hide_${context}_observation_fields`;
    this.state = {
      open: currentUser ? !currentUser[this.collapsePreference] : true,
      editingFieldValue: null
    };
  }

  componentDidUpdate( prevProps, prevState ) {
    if ( prevState.open === this.state.open ) {
      this.setOpenStateOnConfigUpdate( );
    }
  }

  setOpenStateOnConfigUpdate( ) {
    const { config } = this.props;
    if ( config.currentUser
      && config.currentUser[this.collapsePreference] === this.state.open ) {
      this.setState( { open: !config.currentUser[this.collapsePreference] } );
    }
  }

  render( ) {
    const {
      observation,
      config,
      addObservationFieldValue,
      removeObservationFieldValue,
      updateObservationFieldValue,
      updateSession
    } = this.props;
    const {
      editingFieldValue,
      open
    } = this.state;
    const loggedIn = config && config.currentUser;
    if ( !observation || !observation.user || ( _.isEmpty( observation.ofvs ) && !loggedIn ) ) {
      return ( <span /> );
    }
    const sortedFieldValues = _.sortBy( observation.ofvs, ofv => (
      `${ofv.value ? "a" : "z"}:${ofv.name}:${ofv.value}`
    ) );
    let addValueInput;
    if ( loggedIn ) {
      let disabled = false;
      let placeholder;
      const viewerIsObserver = observation.user && config.currentUser.id === observation.user.id;
      const viewerIsCurator = config.currentUser.roles.indexOf( "curator" ) >= 0;
      if ( this.observerPrefersFieldsBy === "observer" && !viewerIsObserver ) {
        disabled = true;
        placeholder = I18n.t( "views.observations.show.observer_does_not_allow_observation_fields" );
      } else if ( this.observerPrefersFieldsBy === "curators" && !viewerIsObserver && !viewerIsCurator ) {
        disabled = true;
        placeholder = I18n.t( "views.observations.show.observer_only_allows_curators_to_add_fields" );
      }
      addValueInput = (
        <div className="form-group">
          <ObservationFieldInput
            notIDs={
              _.compact( _.uniq( _.map( observation.ofvs, ofv => (
                ofv.observation_field && ofv.observation_field.id ) ) ) )
            }
            onSubmit={r => {
              addObservationFieldValue( r );
            }}
            placeholder={placeholder}
            config={config}
            disabled={disabled}
          />
        </div>
      );
    }
    const panelContent = (
      <div>
        { sortedFieldValues.map( ofv => {
          if ( editingFieldValue && editingFieldValue.uuid === ofv.uuid ) {
            return (
              <ObservationFieldInput
                observationField={ofv.observation_field}
                observationFieldValue={ofv.value}
                observationFieldTaxon={ofv.taxon}
                key={`editing-field-value-${ofv.uuid}`}
                setEditingFieldValue={fieldValue => {
                  this.setState( { editingFieldValue: fieldValue } );
                }}
                editing
                originalOfv={ofv}
                hideFieldChooser
                onCancel={( ) => {
                  this.setState( { editingFieldValue: null } );
                }}
                onSubmit={r => {
                  if ( r.value !== ofv.value ) {
                    updateObservationFieldValue( ofv.uuid, r );
                  }
                  this.setState( { editingFieldValue: null } );
                }}
                config={config}
              />
            );
          }
          return (
            <ObservationFieldValue
              ofv={ofv}
              key={`field-value-${ofv.uuid || ofv.observation_field.uuid}`}
              setEditingFieldValue={fieldValue => {
                this.setState( { editingFieldValue: fieldValue } );
              }}
              config={config}
              observation={observation}
              removeObservationFieldValue={removeObservationFieldValue}
            />
          );
        } ) }
        { addValueInput }
      </div>
    );

    const count = sortedFieldValues.length > 0 ? `(${sortedFieldValues.length})` : "";
    return (
      <div className="ObservationFields collapsible-section">
        <h4
          className="collapsible"
          onClick={( ) => {
            if ( loggedIn ) {
              updateSession( {
                [this.collapsePreference]: open
              } );
            }
            this.setState( { open: !open } );
          }}
        >
          <i className={`fa fa-chevron-circle-${open ? "down" : "right"}`} />
          { I18n.t( "observation_fields" ) }
          { " " }
          { count }
        </h4>
        <Panel id="observation-fields-panel" expanded={open} onToggle={() => {}}>
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
  context: PropTypes.string
};

ObservationFields.defaultProps = {
  context: "obs_show"
};

export default ObservationFields;
