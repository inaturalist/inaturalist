import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col, Overlay, Popover } from "react-bootstrap";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";
import RegularForm from "./regular_form";
import UmbrellaForm from "./umbrella_form";
import SharedForm from "./shared_form";
import ConfirmModalContainer from "../containers/confirm_modal_container";

class ProjectForm extends React.Component {
  render( ) {
    const {
      project,
      addManager,
      removeProjectUser,
      submitProject } = this.props;
    if ( !project ) { return ( <span /> ); }
    return (
      <div className="Form">
        <SharedForm { ...this.props } />
        { project.project_type === "umbrella" ?
            ( <UmbrellaForm { ...this.props } /> ) :
            ( <RegularForm { ...this.props } /> )
        }
        <Grid>
          <Row>
            <Col xs={12}>
              <div className="preview">
                <button
                  className="btn-white"
                  onClick={ ( ) =>
                    window.open( `/observations?${project.previewSearchParamsString}`, "_blank" ) }
                >
                  <i className="fa fa-external-link" />
                  { I18n.t( "preview_observations" ) }
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
                ref="ua"
                afterSelect={ e => {
                  e.item.id = e.item.user_id;
                  addManager( e.item );
                  this.refs.ua.inputElement( ).val( "" );
                } }
                bootstrapClear
                placeholder={ I18n.t( "user_autocomplete_placeholder" ) }
              />
              { !_.isEmpty( project.undestroyedAdmins ) && (
                <div className="icon-previews">
                  { _.map( project.undestroyedAdmins, admin => (
                    <div className="badge-div" key={ `user_rule_${admin.user.id}` }>
                      <span className="badge">
                        { admin.user.login }
                        { ( admin.user.id === project.user_id ) ? " (owner)" : (
                          <i
                            className="fa fa-times-circle-o"
                            onClick={ ( ) => removeProjectUser( admin ) }
                          />
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
              * { I18n.t( "required_" ) }
              <div className="buttons">
                <button
                  className="btn btn-default done"
                  ref="doneButton"
                  onClick={ ( ) => submitProject( ) }
                  disabled={
                    project.saving || !_.isEmpty( _.compact( _.values( project.errors ) ) )
                  }
                >{ project.saving ? I18n.t( "saving" ) : I18n.t( "done" ) }</button>
                { project.errors.description && (
                  <Overlay
                    show
                    placement="top"
                    target={ ( ) => this.refs.doneButton }
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
                  className="btn btn-default"
                  onClick={ ( ) => {
                    project.id ?
                      window.location = `/projects/${project.slug}` :
                      this.props.removeProject( );
                  } }
                >{ I18n.t( "cancel" ) }</button>
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
  project: PropTypes.object,
  onFileDrop: PropTypes.func,
  addManager: PropTypes.func,
  removeProjectUser: PropTypes.func,
  showObservationPreview: PropTypes.func,
  submitProject: PropTypes.func,
  removeProject: PropTypes.func
};

export default ProjectForm;
