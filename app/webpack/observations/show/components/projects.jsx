import _ from "lodash";
import React, { PropTypes } from "react";
import { Panel } from "react-bootstrap";
import ProjectListing from "./project_listing";

class Projects extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      open: false
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
    const input = $( ".Projects .panel-collapse input" );
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
    if ( !observation ) {
      return ( <span /> );
    }
    let addProjectLink;
    let addProjectInput;
    if ( loggedIn ) {
      addProjectLink = (
        <span
          className="add"
          onClick={ ( ) => this.setState( { open: !this.state.open } ) }
        >Add To Project</span>
      );
      addProjectInput = (
        <Panel collapsible expanded={ this.state.open }>
          <form onSubmit={ this.chooseFirstProject }>
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder={ I18n.t( "add_to_a_project" ) }
              />
            </div>
          </form>
        </Panel>
      );
    }
    const count = observation.project_observations.length;
    return (
      <div className="Projects">
        <h4>This observation is in { count } projects { addProjectLink }</h4>
        { addProjectInput }
        { observation.project_observations.map( po => (
          <ProjectListing
            key={ po.project.id }
            projectObservation={ po }
            { ...this.props }
          />
        ) ) }
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
  setErrorModalState: PropTypes.func
};

export default Projects;
