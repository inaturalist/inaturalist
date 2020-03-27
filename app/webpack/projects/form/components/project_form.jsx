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

class ProjectForm extends React.Component {
  constructor( props ) {
    super( props );
    this.ua = React.createRef( );
    this.doneButton = React.createRef( );
  }

  render( ) {
    const {
      project,
      addManager,
      removeProjectUser,
      confirmSubmitProject,
      removeProject
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
                  Preview Observations With These Settings
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
                  { _.map( project.undestroyedAdmins, admin => (
                    <div className="badge-div" key={`user_rule_${admin.user.id}`}>
                      <span className="badge">
                        { admin.user.login }
                        { ( admin.user.id === project.user_id ) ? " (owner)" : (
                          <button
                            type="button"
                            className="btn btn-nostyle"
                            onClick={( ) => removeProjectUser( admin )}
                          >
                            <i className="fa fa-times-circle-o" />
                          </button>
                        ) }
                      </span>
                    </div>
                  ) ) }
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
  removeProjectUser: PropTypes.func,
  showObservationPreview: PropTypes.func,
  confirmSubmitProject: PropTypes.func,
  removeProject: PropTypes.func,
  updateProject: PropTypes.func
};

export default ProjectForm;
