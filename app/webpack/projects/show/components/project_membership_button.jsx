import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";

class ProjectMembershipButton extends React.Component {
  constructor( props ) {
    super( props );
    let curatorCoordinateAccessFor = "none";
    let prefersUpdates = false;
    const { projectUser } = props;
    if ( projectUser ) {
      curatorCoordinateAccessFor = projectUser.prefers_curator_coordinate_access_for;
      prefersUpdates = projectUser.prefers_updates;
    }
    this.state = {
      modalVisible: false,
      detailsOpen: false,
      curatorCoordinateAccessFor,
      prefersUpdates
    };
  }

  componentDidUpdate( prevProps ) {
    const { projectUser: oldProjectUser } = prevProps;
    const { projectUser } = this.props;
    if (
      ( !oldProjectUser && projectUser )
      || ( oldProjectUser && projectUser && projectUser.id !== oldProjectUser.id )
    ) {
      this.setState( {
        curatorCoordinateAccessFor: projectUser.prefers_curator_coordinate_access_for
      } );
      this.setState( { prefersUpdates: projectUser.prefers_updates } );
    }
  }

  render( ) {
    const {
      project,
      projectUser,
      updateProjectUser,
      leaveProject
    } = this.props;
    if ( !projectUser ) {
      return <div />;
    }
    const {
      modalVisible,
      curatorCoordinateAccessFor,
      prefersUpdates,
      detailsOpen
    } = this.state;
    let trustingFields;
    if (
      project.prefers_user_trust
      || ["any", "taxon"].includes( projectUser.prefers_curator_coordinate_access_for )
    ) {
      trustingFields = (
        <div>
          <h4>{ I18n.t( "trust_this_project_with_your_private_coordinates?" ) }</h4>
          <div className="radio">
            <label>
              <input
                type="radio"
                name="prefers_curator_coordinate_access_for"
                checked={curatorCoordinateAccessFor === "none"}
                onChange={( ) => this.setState( { curatorCoordinateAccessFor: "none" } )}
              />
              { " " }
              { I18n.t( "no" ) }
            </label>
          </div>
          <div className="radio">
            <label>
              <input
                type="radio"
                name="prefers_curator_coordinate_access_for"
                checked={curatorCoordinateAccessFor === "any"}
                onChange={( ) => this.setState( { curatorCoordinateAccessFor: "any" } )}
              />
              { " " }
              { I18n.t( "yes_for_any_of_my_observations" ) }
            </label>
          </div>
          <div className="radio">
            <label>
              <input
                type="radio"
                name="prefers_curator_coordinate_access_for"
                checked={curatorCoordinateAccessFor === "taxon"}
                onChange={( ) => this.setState( { curatorCoordinateAccessFor: "taxon" } )}
              />
              { " " }
              { I18n.t( "yes_but_only_for_threatened" ) }
            </label>
          </div>
          <div className="alert alert-warning">
            <strong>{ I18n.t( "please_be_careful!" ) }</strong>
            <p>{ I18n.t( "project_coordinate_access_warning" ) }</p>
          </div>
          <div className="collapsible-section">
            <button
              type="button"
              className="btn btn-nostyle"
              onClick={( ) => this.setState( { detailsOpen: !detailsOpen } )}
            >
              <h5>
                <i className={`fa fa-chevron-circle-${detailsOpen ? "down" : "right"}`} />
                { I18n.t( "about_trusting_projects" ) }
              </h5>
            </button>
            <div className={`collapsible-content ${detailsOpen ? "open" : "closed"}`}>
              <p>{ I18n.t( "about_trusting_projects_overview" ) }</p>
              <p>{ I18n.t( "about_trusting_projects_project_managers_are" ) }</p>
              <div className="stacked row">
                { project.admins.map( manager => (
                  <div className="col-xs-3" key={`admin-${manager.id}`}>
                    <UserImage user={manager.user} />
                    { " " }
                    <UserLink user={manager.user} />
                  </div>
                ) ) }
              </div>
              <p>{ I18n.t( "about_trusting_projects_you_can_choose" ) }</p>
              <ul>
                <li>
                  <p
                    dangerouslySetInnerHTML={{
                      __html: I18n.t( "bold_label_colon_value_html", {
                        label: I18n.t( "about_trusting_projects_options_any" ),
                        value: I18n.t( "about_trusting_projects_options_any_desc" )
                      } )
                    }}
                  />
                </li>
                <li>
                  <p
                    dangerouslySetInnerHTML={{
                      __html: I18n.t( "bold_label_colon_value_html", {
                        label: I18n.t( "about_trusting_projects_options_taxon" ),
                        value: I18n.t( "about_trusting_projects_options_taxon_desc" )
                      } )
                    }}
                  />
                </li>
              </ul>
              <p>{ I18n.t( "about_trusting_projects_warning" ) }</p>
            </div>
          </div>
        </div>
      );
    }
    return (
      <div className="ProjectMembershipButton">
        <button
          type="button"
          className="btn btn-nostyle btn-xs header-link-btn"
          onClick={( ) => this.setState( { modalVisible: true } )}
        >
          <i className="fa fa-cog" />
          { " " }
          { I18n.t( "your_membership" ) }
        </button>
        <Modal
          show={modalVisible}
          onHide={( ) => this.setState( { modalVisible: false } )}
        >
          <Modal.Header closeButton>
            <Modal.Title>
              { I18n.t( "your_membership" ) }
            </Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <div className="stacked">
              <h4>{ I18n.t( "receive_project_journal_notifications?" ) }</h4>
              <div className="radio">
                <label>
                  <input
                    type="radio"
                    name="prefers_updates"
                    checked={!prefersUpdates}
                    onChange={( ) => this.setState( { prefersUpdates: false } )}
                  />
                  { " " }
                  { I18n.t( "no" ) }
                </label>
              </div>
              <div className="radio">
                <label>
                  <input
                    type="radio"
                    name="prefers_updates"
                    checked={!!prefersUpdates}
                    onChange={( ) => this.setState( { prefersUpdates: true } )}
                  />
                  { " " }
                  { I18n.t( "yes" ) }
                </label>
              </div>
            </div>
            { trustingFields }
          </Modal.Body>
          <Modal.Footer>
            <button
              type="button"
              className="btn btn-default pull-left"
              confirm="Are you sure?"
              onClick={( ) => {
                this.setState( { modalVisible: false } );
                leaveProject( );
              }}
            >
              { I18n.t( "leave" ) }
            </button>
            <button
              type="button"
              className="btn btn-default"
              onClick={( ) => this.setState( { modalVisible: false } )}
            >
              { I18n.t( "cancel" ) }
            </button>
            <button
              type="button"
              className="btn btn-success"
              onClick={( ) => {
                updateProjectUser( {
                  id: projectUser.id,
                  prefers_curator_coordinate_access_for: curatorCoordinateAccessFor,
                  prefers_updates: prefersUpdates
                } );
                this.setState( { modalVisible: false } );
              }}
            >
              { I18n.t( "save" ) }
            </button>
          </Modal.Footer>
        </Modal>
      </div>
    );
  }
}

ProjectMembershipButton.propTypes = {
  project: PropTypes.object,
  projectUser: PropTypes.object,
  updateProjectUser: PropTypes.func.isRequired,
  leaveProject: PropTypes.func.isRequired
};

export default ProjectMembershipButton;
