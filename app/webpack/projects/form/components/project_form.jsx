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
                  Preview Observations
                </button>
              </div>
            </Col>
          </Row>
          <Row>
            <Col xs={12}>
              { }
            </Col>
          </Row>
          <Row>
            <Col xs={4}>
              <label>Admin(s)</label>
              <div className="help-text">
                Note: these users will be able to edit ALL project details including admins.
              </div>
              <UserAutocomplete
                ref="ua"
                afterSelect={ e => {
                  e.item.id = e.item.user_id;
                  addManager( e.item );
                  this.refs.ua.inputElement( ).val( "" );
                } }
                bootstrapClear
                placeholder={ "kueda, 1001, etc." }
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
              * Required
              <div className="buttons">
                <button
                  className="btn btn-default done"
                  ref="doneButton"
                  onClick={ ( ) => submitProject( ) }
                  disabled={
                    project.saving || !_.isEmpty( _.compact( _.values( project.errors ) ) )
                  }
                >{ project.saving ? "Saving..." : "Done" }</button>
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
                      Check above for errors
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
                >Cancel</button>
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
