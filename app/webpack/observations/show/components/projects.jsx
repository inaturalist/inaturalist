import _ from "lodash";
import React, { PropTypes } from "react";
import { Panel } from "react-bootstrap";
import ProjectListing from "./project_listing";

class Projects extends React.Component {

  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_projects : true
    };
    this.setUpProjectAutocomplete = this.setUpProjectAutocomplete.bind( this );
  }

  componentDidMount( ) {
    this.setUpProjectAutocomplete( );
  }

  componentDidUpdate( ) {
    this.setUpProjectAutocomplete( );
  }

  setUpProjectAutocomplete( ) {
    const input = $( ".Projects .form-group input" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.autocomplete( "destroy" );
      input.removeData( "uiAutocomplete" );
    }
    input.projectAutocomplete( {
      resetOnChange: false,
      idEl: $( "<input/>" ),
      notIDs: _.map( this.props.observation.project_observations, "project_id" ),
      allowEnterSubmit: true,
      selectFirstMatch: true,
      currentUsersProjects: true,
      onResults: items => {
        // don't want to add the failed class if there is no search term
        if ( items !== null && items.length === 0 && input.val( ) ) {
          input.addClass( "failed" );
        } else {
          input.removeClass( "failed" );
        }
      },
      afterSelect: p => {
        if ( p ) {
          const project = p.item;
          this.props.addToProject( project );
        }
        input.val( "" ).blur( );
      }
    } );
  }

  chooseFirstProject( e ) {
    e.preventDefault( );
    const input = $( ".Projects .panel-group input" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.trigger( "selectFirst" );
    }
  }

  render( ) {
    const observation = this.props.observation;
    const config = this.props.config;
    const loggedIn = config && config.currentUser;
    if ( !observation || !observation.user ||
         ( !loggedIn && observation.project_observations.length === 0 ) ) {
      return ( <span /> );
    }
    let addProjectInput;
    if ( loggedIn ) {
      addProjectInput = (
        <form onSubmit={ this.chooseFirstProject }>
          <div className="form-group">
            <input
              type="text"
              className="form-control"
              placeholder={ I18n.t( "add_to_a_project" ) }
            />
          </div>
        </form>
      );
    }
    const count = observation.project_observations.length > 0 ?
      `(${observation.project_observations.length})` : "";
    return (
      <div className="Projects">
        <h4
          className="collapsable"
          onClick={ ( ) => {
            if ( loggedIn ) {
              this.props.updateSession( { prefers_hide_obs_show_projects: this.state.open } );
            }
            this.setState( { open: !this.state.open } );
          } }
        >
          <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
          { I18n.t( "projects" ) } { count }
        </h4>
        <Panel collapsible expanded={ this.state.open }>
          { addProjectInput }
          { observation.project_observations.map( po => (
            <ProjectListing
              key={ po.project.id }
              projectObservation={ po }
              { ...this.props }
            />
          ) ) }
        </Panel>
      </div>
    );
  }
}

Projects.propTypes = {
  addToProject: PropTypes.func,
  joinProject: PropTypes.func,
  updateCuratorAccess: PropTypes.func,
  removeFromProject: PropTypes.func,
  config: PropTypes.object,
  observation: PropTypes.object,
  setErrorModalState: PropTypes.func,
  updateSession: PropTypes.func
};

export default Projects;
