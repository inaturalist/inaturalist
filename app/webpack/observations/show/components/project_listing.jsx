import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown, MenuItem, Panel } from "react-bootstrap";
import ObservationFieldValue from "./observation_field_value";
import ObservationFieldInput from "./observation_field_input";

class ProjectListing extends React.Component {
  constructor( ) {
    super( );
    this.state = { fieldsPanelOpen: false };
    this.settingsMenu = this.settingsMenu.bind( this );
  }

  settingsMenu( obj ) {
    const isProjectObservation = !!obj.uuid;
    const currentUser = this.props.config && this.props.config.currentUser;
    const menuItems = [];
    if ( isProjectObservation && currentUser.id === this.props.observation.user.id ) {
      const allowsAccess = obj.preferences && obj.preferences.allows_curator_coordinate_access;
      menuItems.push( (
        <div key={`project-allow-${obj.project.id}`} className="allow">
          <input
            type="checkbox"
            defaultChecked={allowsAccess}
            id={`project-allow-input-${obj.project.id}`}
            onClick={( ) => {
              this.props.updateCuratorAccess( obj, allowsAccess ? 0 : 1 );
            }}
          />
          <label htmlFor={`project-allow-input-${obj.project.id}`}>
            { I18n.t( "allow_curator_access" ) }
          </label>
          <div className="text-muted">
            { I18n.t( "allow_project_curators_to_view_your_private_coordinates" ) }
          </div>
        </div>
      ) );
      menuItems.push( ( <MenuItem divider key="project-allow-divider" /> ) );
    }
    if ( !obj.current_user_is_member ) {
      menuItems.push( (
        <MenuItem
          key={`project-join-${obj.project.id}`}
          eventKey="join"
        >
          { I18n.t( "join_this_project" ) }
        </MenuItem>
      ) );
    }
    if ( isProjectObservation ) {
      menuItems.push( (
        <MenuItem
          key={`project-remove-${obj.project.id}`}
          eventKey="delete"
        >
          { I18n.t( "remove_from_project" ) }
        </MenuItem>
      ) );
    }
    if ( isProjectObservation && obj.current_user_is_member ) {
      if (
        obj.project.project_observation_fields
        && obj.project.project_observation_fields.length > 0
      ) {
        menuItems.push( (
          <MenuItem
            key="edit-project-observation-fields"
            eventKey="edit-project-observation-fields"
          >
            { I18n.t( "fill_out_project_observation_fields" ) }
          </MenuItem>
        ) );
      }
    }
    if ( obj.current_user_is_member ) {
      menuItems.push( (
        <MenuItem
          key={`project-settings-${obj.project.id}`}
          eventKey="projectSettings"
          href={`/projects/${obj.project.slug}/contributors/${currentUser.login}`}
        >
          { I18n.t( "edit_your_settings_for_this_project" ) }
        </MenuItem>
      ) );
    }
    if ( isProjectObservation ) {
      menuItems.push( (
        <MenuItem
          key={`project-global-${obj.project.id}`}
          eventKey="globalSettings"
          href="/users/edit#projects"
        >
          { I18n.t( "edit_your_global_project_settings" ) }
        </MenuItem>
      ) );
    }
    return (
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={key => {
            if ( key === "join" ) {
              this.props.joinProject( obj.project );
            } else if ( key === "delete" ) {
              this.props.removeFromProject( obj.project );
            } else if ( key === "edit-project-observation-fields" ) {
              this.props.showProjectFieldsModal( obj.project );
            }
          }}
        >
          <Dropdown.Toggle noCaret>
            <i className="fa fa-cog" />
          </Dropdown.Toggle>
          <Dropdown.Menu className="dropdown-menu-right">
            { menuItems }
          </Dropdown.Menu>
        </Dropdown>
      </span>
    );
  }

  render( ) {
    let observationFieldLink;
    let observationFields;
    const {
      config,
      displayObject,
      observation
    } = this.props;
    const { fieldsPanelOpen } = this.state;
    const { project } = displayObject;
    const isProjectObservation = !!displayObject.uuid;
    // const observation = this.props.observation;
    const viewerIsObserver = config && config.currentUser
      && config.currentUser.id === observation.user.id;
    const viewerIsAdder = isProjectObservation && config && config.currentUser
      && config.currentUser.id === displayObject.user_id;
    const viewerIsCurator = config && config.currentUser
      && _.includes( config.currentUser.curator_project_ids, project.id );
    if ( isProjectObservation ) {
      const fields = project.project_observation_fields;
      if ( fields && fields.length > 1 ) {
        const fieldIDs = project.project_observation_fields
          .map( pof => ( pof.observation_field.id ) );
        const projectFieldValues = _.filter( observation.ofvs, ofv => (
          ofv.observation_field && _.includes( fieldIDs, ofv.observation_field.id ) ) );
        if ( projectFieldValues.length > 0 ) {
          observationFieldLink = (
            <button
              type="button"
              className="fieldLink btn btn-nostyle"
              onClick={( ) => this.setState( { fieldsPanelOpen: !fieldsPanelOpen } )}
            >
              { I18n.t( "observation_fields" ) }
              { " " }
              <i className="fa fa-angle-double-down" />
            </button>
          );
          observationFields = (

            <Panel expanded={this.state.fieldsPanelOpen} onToggle={() => null}>
              <Panel.Collapse>
                <Panel.Body>
                  { projectFieldValues.map( ofv => {
                    if (
                      this.state.editingFieldValue
                      && this.state.editingFieldValue.uuid === ofv.uuid
                    ) {
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
                              this.props.updateObservationFieldValue( ofv.uuid, r );
                            }
                            this.setState( { editingFieldValue: null } );
                          }}
                        />
                      );
                    }
                    return (
                      <ObservationFieldValue
                        ofv={ofv}
                        key={`field-value-${ofv.uuid || ofv.observation_field.id}`}
                        setEditingFieldValue={fieldValue => {
                          this.setState( { editingFieldValue: fieldValue } );
                        }}
                        {...this.props}
                      />
                    );
                  } ) }
                </Panel.Body>
              </Panel.Collapse>
            </Panel>
          );
        }
      }
    }
    return (
      <div className="projectEntry">
        <div className="project" key={`project-${project.id}`}>
          <div className="squareIcon">
            <a href={`/projects/${project.id}`}>
              <img src={project.icon} alt={project.title} />
            </a>
          </div>
          <div className="info">
            <div className="title">
              <a href={`/projects/${project.id}`}>
                { project.title }
              </a>
            </div>
            { observationFieldLink }
          </div>
          { ( viewerIsObserver || viewerIsAdder || viewerIsCurator )
            ? this.settingsMenu( displayObject )
            : ""
          }
        </div>
        { observationFields }
      </div>
    );
  }
}

ProjectListing.propTypes = {
  joinProject: PropTypes.func,
  removeFromProject: PropTypes.func,
  updateCuratorAccess: PropTypes.func,
  config: PropTypes.object,
  observation: PropTypes.object,
  displayObject: PropTypes.object,
  removeObservationFieldValue: PropTypes.func,
  updateObservationFieldValue: PropTypes.func,
  showProjectFieldsModal: PropTypes.func
};

export default ProjectListing;
