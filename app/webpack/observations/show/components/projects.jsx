import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Panel } from "react-bootstrap";
import ProjectListing from "./project_listing";

class Projects extends React.Component {
  static chooseFirstProject( e ) {
    e.preventDefault( );
    const input = $( ".Projects .panel-group input" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.trigger( "selectFirst" );
    }
  }

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
      notTypes: ["collection", "umbrella"],
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

  render( ) {
    const { observation, config, collapsible } = this.props;
    const loggedIn = config && config.currentUser;

    const projectsOrProjObs = observation.non_traditional_projects
      ? _.cloneDeep( observation.non_traditional_projects )
      : [];
    _.each( observation.project_observations, po => {
      // trying to avoid duplicate project listing. This can happen for formerly
      // traditional projects that have been turned into collection projects
      const duplicate = _.find( projectsOrProjObs, ppo => (
        ( ppo.project_id && po.project_id && ppo.project_id === po.project_id )
        || (
          ppo.project && po.project && ppo.project.id === po.project.id
        )
      ) );
      if ( !duplicate ) {
        projectsOrProjObs.push( po );
      }
    } );
    if (
      !observation
      || !observation.user
      || (
        !loggedIn
        && projectsOrProjObs.length === 0
      )
    ) {
      return ( <span /> );
    }
    let addProjectInput;
    if ( loggedIn ) {
      let projectAdditionNotice;
      if ( config.currentUser.id !== observation.user.id && observation.user.preferences ) {
        if ( observation.user.preferences.prefers_project_addition_by === "none" ) {
          addProjectInput = (
            <p className="text-muted">{ I18n.t( "observer_prefers_no_traditional_project_addition" ) }</p>
          );
        } else if ( observation.user.preferences.prefers_project_addition_by === "joined" ) {
          projectAdditionNotice = (
            <p className="text-muted">{ I18n.t( "observer_prefers_addition_to_traditional_projects_joined" ) }</p>
          );
        }
      }
      addProjectInput = addProjectInput || (
        <form onSubmit={Projects.chooseFirstProject}>
          <div className="form-group">
            <input
              type="text"
              className="form-control"
              placeholder={I18n.t( "add_to_a_project" )}
            />
          </div>
          { projectAdditionNotice }
        </form>
      );
    }

    const panelContent = (
      <div>
        { addProjectInput }
        { projectsOrProjObs.map( obj => (
          <ProjectListing
            key={obj.project.id}
            displayObject={obj}
            {...this.props}
          />
        ) ) }
      </div>
    );
    if ( !collapsible ) {
      return (
        <div className="Projects">
          { panelContent }
        </div>
      );
    }

    const count = projectsOrProjObs.length > 0
      ? `(${projectsOrProjObs.length})`
      : "";
    const sectionOpen = this.state.open;
    return (
      <div className="Projects collapsible-section">
        <button
          type="button"
          className="btn btn-nostyle"
          onClick={( ) => {
            if ( loggedIn ) {
              this.props.updateSession( { prefers_hide_obs_show_projects: sectionOpen } );
            }
            this.setState( { open: !sectionOpen } );
          }}
        >
          <h4 className="collapsible">
            <i className={`fa fa-chevron-circle-${this.state.open ? "down" : "right"}`} />
            { I18n.t( "projects" ) }
            { " " }
            { count }
          </h4>
        </button>
        <Panel id="projects-panel" expanded={this.state.open} onToggle={() => null}>
          <Panel.Collapse>
            <Panel.Body>
              { panelContent }
            </Panel.Body>
          </Panel.Collapse>
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
  updateSession: PropTypes.func,
  showProjectFieldsModal: PropTypes.func,
  collapsible: PropTypes.bool
};

Projects.defaultProps = {
  collapsible: true
};

export default Projects;
