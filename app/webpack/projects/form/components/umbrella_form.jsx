import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import ProjectSelector from "./project_selector";

class UmbrellaForm extends React.Component {
  render( ) {
    const {
      project,
      updateProject
    } = this.props;
    return (
      <div id="UmbrellaForm" className="Form">
        <Grid>
          <Row className="text">
            <Col xs={12}>
              <h2>{ I18n.t( "observation_requirements" ) }</h2>
              <div className="help-text">
                { I18n.t( "views.projects.new.please_specify_the_requirements" ) }
              </div>
            </Col>
          </Row>
          <Row className="first-row">
            <Col xs={4}>
              <ProjectSelector {...this.props} />
            </Col>
          </Row>
          <Row>
            <Col xs={12}>
              <input
                type="checkbox"
                id="project-umbrella-flags"
                defaultChecked={!project.hide_umbrella_map_flags}
                onChange={e => updateProject( { hide_umbrella_map_flags: !e.target.checked } )}
              />
              <label className="inline" htmlFor="project-umbrella-flags">
                { I18n.t( "views.projects.new.show_projects_as_flags" )}
              </label>
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}

UmbrellaForm.propTypes = {
  project: PropTypes.object,
  updateProject: PropTypes.func
};

export default UmbrellaForm;
