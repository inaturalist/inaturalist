import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";

// TODO only show the button if the user does not curate the project

// TODO If the user already trusts the project, button text should say "Remove
// trust for project" or something

// TODO Clicking the button should bring up a modal explaining that you're about
// to join this project and trust the curators with access to the hidden
// coordinates of your observations

// TODO Modal should allow you to choose whether to only share coords hidden by
// threatened taxa or share everything

// TODO Modal must explain that you will be notified when the project changes
// their curators, but you are basically trusting the existing curators to
// choose trustworthy people

// TODO When you already trust the project, the modal should explain what
// untrusting will do

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
      this.setState( { curatorCoordinateAccessFor: projectUser.prefers_curator_coordinate_access_for } );
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
    return (
      <div className="ProjectMembershipButton">
        <button
          type="button"
          className="btn btn-default"
          onClick={( ) => this.setState( { modalVisible: true } )}
        >
          Your Membership
        </button>
        <Modal
          show={modalVisible}
          onHide={( ) => this.setState( { modalVisible: false } )}
        >
          <Modal.Header closeButton>
            <Modal.Title>
              Your Membership
            </Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <div className="stacked">
              <h4>Receive project journal notifications?</h4>
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
            <h4>Trust this project with hidden coordinates?</h4>
            <div className="radio">
              <label>
                <input
                  type="radio"
                  name="prefers_curator_coordinate_access_for"
                  checked={curatorCoordinateAccessFor === "none"}
                  onChange={( ) => this.setState( { curatorCoordinateAccessFor: "none" } )}
                />
                { " " }
                No
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
                Yes, for any of my observations
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
                Yes, but only for my observations of threatened taxa, not when I've set the geoprivacy
              </label>
            </div>
            <div className="collapsible-section">
              <button
                type="button"
                className="btn btn-nostyle"
                onClick={( ) => this.setState( { detailsOpen: !detailsOpen } )}
              >
                <h5>
                  <i className={`fa fa-chevron-circle-${detailsOpen ? "down" : "right"}`} />
                  About Trusting Projects
                </h5>
              </button>
              <div className={`collapsible-content ${detailsOpen ? "open" : "closed"}`}>
                <p>
                  Granting access to your hidden coordinates will allow the
                  managers of this project to see the true, unobscured location
                  of of your observations in this project. This is extremeley
                  important in situations where scientists or resource managers
                  need access to exact coordinates for analysis and
                  decision-making.
                </p>
                <p>
                  The project managers who will have access to your hidden
                  coordinates are:
                </p>
                <div className="stacked row">
                  { project.admins.map( manager => (
                    <div className="col-xs-3" key={`admin-${manager.id}`}>
                      <UserImage user={manager.user} />
                      { " " }
                      <UserLink user={manager.user} />
                    </div>
                  ) ) }
                </div>
                <p>
                  You can choose to share hidden coordinates for
                </p>
                <ul>
                  <li>
                    <p>
                      <strong>All your observations in this project</strong>:
                      { " " }
                      This includes observations where you have set the
                      geoprivacy to "obscured" or "private," e.g. observations
                      from your backyard or spots you don't want other people to
                      know about.
                    </p>
                  </li>
                  <li>
                    <p>
                      <strong>Only your observations in this project that have obscured coordinates because of threatened taxa</strong>:
                      { " " }
                      Many projects just need access to coordinates that are
                      obscured because the observation depicts a threatened
                      taxon.
                    </p>
                  </li>
                </ul>
                <p>
                  Note that project managers can change the project parameters to
                  include any of your observations, and they can add or remove
                  project managers at any time. You will receive notifications about
                  these changes, but you are essentially trusting this project with
                  your private location data, so be careful.
                </p>
              </div>
            </div>
          </Modal.Body>
          <Modal.Footer>
            <button
              type="button"
              className="btn btn-default pull-left"
              confirm="Are you sure?"
              onClick={( ) => leaveProject( )}
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
  // trustProject: PropTypes.func
  updateProjectUser: PropTypes.func,
  leaveProject: PropTypes.func
};

export default ProjectMembershipButton;
