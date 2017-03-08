import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown, MenuItem, Panel } from "react-bootstrap";
import ObservationFieldValue from "./observation_field_value";

class ProjectListing extends React.Component {
  constructor( ) {
    super( );
    this.state = { fieldsPanelOpen: false };
    this.settingsMenu = this.settingsMenu.bind( this );
  }

  settingsMenu( po ) {
    return (
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={ ( ) => {
            this.props.removeFromProject( po.project );
          } }
        >
          <Dropdown.Toggle noCaret>
            <i className="fa fa-cog" />
          </Dropdown.Toggle>
          <Dropdown.Menu className="dropdown-menu-right">
            <MenuItem
              key={ `project-remove-${po.project.id}` }
              eventKey="delete"
            >
              Remove
            </MenuItem>
          </Dropdown.Menu>
        </Dropdown>
      </span>
    );
  }

  render( ) {
    let observationFieldLink;
    let observationFields;
    const po = this.props.projectObservation;
    const observation = this.props.observation;
    const config = this.props.config;
    const viewerIsObserver = config && config.currentUser &&
      config.currentUser.id === observation.user.id;
    const fields = po.project.project_observation_fields;
    if ( fields && fields.length > 1 ) {
      const fieldIDs = po.project.project_observation_fields.
        map( pof => ( pof.observation_field.id ) );
      const projectFieldValues = _.filter( observation.ofvs, ofv => (
        _.includes( fieldIDs, ofv.field_id ) ) );
      if ( projectFieldValues.length > 0 ) {
        observationFieldLink = (
          <span
            className="fieldLink"
            onClick={ ( ) => this.setState( { fieldsPanelOpen: !this.state.fieldsPanelOpen } ) }
          >
            Observation Fields <i className="fa fa-angle-double-down" />
          </span>
        );
        observationFields = (
          <Panel collapsible expanded={ this.state.fieldsPanelOpen }>
            { projectFieldValues.map( ofv => ( <ObservationFieldValue ofv={ ofv } /> ) ) }
          </Panel>
        );
      }
    }
    return (
      <div className="projectEntry">
        <div className="project" key={ `project-${po.project.id}` }>
          <div className="image">
            <a href={ `/projects/${po.project.id}` }>
              <img src={po.project.icon} />
            </a>
          </div>
          <div className="info">
            <div className="title">
              <a href={ `/projects/${po.project.id}` }>
                { po.project.title }
              </a>
            </div>
            { observationFieldLink }
          </div>
          { viewerIsObserver && this.settingsMenu( po ) }
        </div>
        { observationFields }
      </div>
    );
  }
}

ProjectListing.propTypes = {
  removeFromProject: PropTypes.func,
  config: PropTypes.object,
  observation: PropTypes.object,
  projectObservation: PropTypes.object
};

export default ProjectListing;
