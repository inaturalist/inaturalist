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
    const { context } = props;
    const currentUser = props.config && props.config.currentUser;
    this.collapsePreference = `prefers_hide_${context}_projects`;
    this.state = {
      open: currentUser ? !currentUser[this.collapsePreference] : true
    };
    this.setUpProjectAutocomplete = this.setUpProjectAutocomplete.bind( this );
  }

  componentDidMount( ) {
    this.setUpProjectAutocomplete( );
  }

  componentDidUpdate( prevProps, prevState ) {
    this.setUpProjectAutocomplete( );
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

  setUpProjectAutocomplete( ) {
    const input = $( ".Projects .form-group input" );
    const opts = {
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
    };
    try {
      input.autocomplete( "option", opts );
    } catch {
      input.projectAutocomplete( opts );
    }
  }

  render( ) {
    const {
      observation,
      config,
      updateSession
    } = this.props;
    const { open } = this.state;
    const loggedIn = config && config.currentUser;
    const userCanInteract = config?.currentUserCanInteractWithResource( observation );

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
        !userCanInteract
        && projectsOrProjObs.length === 0
      )
    ) {
      return ( <span /> );
    }
    let addProjectInput;
    if ( userCanInteract ) {
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
        { _.sortBy( projectsOrProjObs, po => po.project.title ).map( obj => (
          <ProjectListing
            key={obj.project.id}
            displayObject={obj}
            {...this.props}
          />
        ) ) }
      </div>
    );

    const count = projectsOrProjObs.length > 0
      ? `(${projectsOrProjObs.length})`
      : "";
    return (
      <div className="Projects collapsible-section">
        <h4
          className="collapsible"
          onClick={( ) => {
            if ( loggedIn ) {
              updateSession( { [this.collapsePreference]: open } );
            }
            this.setState( { open: !open } );
          }}
        >
          <i className={`fa fa-chevron-circle-${open ? "down" : "right"}`} />
          { I18n.t( "projects" ) }
          { " " }
          { count }
        </h4>
        <Panel id="projects-panel" expanded={open} onToggle={() => null}>
          <Panel.Collapse>{ panelContent }</Panel.Collapse>
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
  context: PropTypes.string
};

Projects.defaultProps = {
  context: "obs_show"
};

export default Projects;
