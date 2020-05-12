import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Grid,
  Row,
  Col,
  Overlay,
  Popover
} from "react-bootstrap";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";
import RegularForm from "./regular_form";
import UmbrellaForm from "./umbrella_form";
import SharedForm from "./shared_form";
import ConfirmModalContainer from "../../shared/containers/confirm_modal_container";
import UserImage from "../../../shared/components/user_image";

class ProjectForm extends React.Component {
  constructor( props ) {
    super( props );
    this.ua = React.createRef( );
    this.doneButton = React.createRef( );
  }

  render( ) {
    const {
      config,
      project,
      addManager,
      removeProjectManager,
      confirmSubmitProject,
      removeProject,
      changeOwner
    } = this.props;
    if ( !project ) { return ( <span /> ); }
    const thereAreErrors = !_.isEmpty( _.compact( _.values( project.errors ) ) );
    return (
      <div className="Form">
        <SharedForm {...this.props} />
        { project.project_type === "umbrella"
          ? <UmbrellaForm {...this.props} />
          : <RegularForm {...this.props} /> }
        <Grid>
          <Row>
            <Col xs={12}>
              <div className="preview">
                <button
                  type="button"
                  className="btn-white"
                  onClick={( ) => window.open( `/observations?${project.previewSearchParamsString}`, "_blank" )}
                >
                  <i className="fa fa-external-link" />
                  { I18n.t( "preview_observations_with_these_observation_requirements" ) }
                </button>
              </div>
            </Col>
          </Row>
          <Row className="admins-row">
            <Col xs={12}>
              <label>{ I18n.t( "admin_s" ) }</label>
              <div className="help-text">
                { I18n.t( "views.projects.new.note_these_users_will_be_able_to_edit" ) }
              </div>
              <UserAutocomplete
                ref={this.ua}
                afterSelect={e => {
                  e.item.id = e.item.user_id;
                  addManager( e.item );
                  this.ua.current.inputElement( ).val( "" );
                }}
                bootstrapClear
                placeholder={I18n.t( "user_autocomplete_placeholder" )}
              />
              { !_.isEmpty( project.undestroyedAdmins ) && (
                <div className="icon-previews">
                  <table className="table">
                    <tbody>
                      { _.map( project.undestroyedAdmins, admin => (
                        <tr className="badge-div" key={`user_rule_${admin.user.id}`}>
                          <td>
                            <UserImage user={admin.user} />
                          </td>
                          <td>
                            <span className="badge">
                              { admin.user.login }
                              { ( admin.user.id === project.user.id ) ? " (owner)" : (
                                <button
                                  type="button"
                                  className="btn btn-nostyle"
                                  onClick={( ) => removeProjectManager( admin )}
                                >
                                  <i className="fa fa-times-circle-o" />
                                </button>
                              ) }
                            </span>
                          </td>
                          <td>
                            {
                              project.user
                                && config.currentUser.id === project.user.id
                                && admin.user.id !== config.currentUser.id
                                && (
                                  <button
                                    className="btn btn-sm btn-default"
                                    type="button"
                                    onClick={( ) => changeOwner( admin )}
                                  >
                                    { I18n.t( "views.projects.edit.make_owner" ) }
                                  </button>
                                )
                            }
                          </td>
                        </tr>
                      ) ) }
                    </tbody>
                  </table>
                </div>
              ) }
            </Col>
          </Row>
          <Row>
            <Col xs={12}>
              { "* " }
              { I18n.t( "required_" ) }
              <div className="buttons">
                <button
                  type="button"
                  className="btn btn-default done"
                  ref={this.doneButton}
                  onClick={( ) => confirmSubmitProject( )}
                  disabled={project.saving || thereAreErrors}
                >
                  { project.saving ? I18n.t( "saving" ) : I18n.t( "done" ) }
                </button>
                { thereAreErrors && (
                  <Overlay
                    show
                    placement="top"
                    target={( ) => this.doneButton.current}
                  >
                    <Popover
                      id="popover-done"
                      className="popover-error"
                    >
                      { I18n.t( "check_above_for_errors" ) }
                    </Popover>
                  </Overlay>
                ) }
                <button
                  type="button"
                  className="btn btn-default"
                  onClick={( ) => {
                    if ( project.id ) {
                      window.location = `/projects/${project.slug}`;
                    } else {
                      removeProject( );
                    }
                  }}
                >
                  { I18n.t( "cancel" ) }
                </button>
              </div>
            </Col>
          </Row>
        </Grid>
        <ConfirmModalContainer />
      </div>
    );
  }
}

ProjectForm.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  onFileDrop: PropTypes.func,
  addManager: PropTypes.func,
  removeProjectManager: PropTypes.func,
  showObservationPreview: PropTypes.func,
  confirmSubmitProject: PropTypes.func,
  removeProject: PropTypes.func,
  updateProject: PropTypes.func,
  changeOwner: PropTypes.func
};

export default ProjectForm;
