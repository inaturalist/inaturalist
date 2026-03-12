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
          <Row>
            <Col xs={4}>
              <label htmlFor="project-sort">
                { I18n.t( "sort_included_projects_on_leaderboard_by" ) }
              </label>
              <select
                id="project-sort"
                className="form-control"
                value={project.umbrella_project_list_sort || "descending"}
                onChange={e => updateProject( { umbrella_project_list_sort: e.target.value } )}
              >
                <option value="alphabetical">{ I18n.t( "alphabetical" ) }</option>
                <option value="descending">{ I18n.t( "count_descending" ) }</option>
                <option value="ascending">{ I18n.t( "count_ascending" ) }</option>
              </select>
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
