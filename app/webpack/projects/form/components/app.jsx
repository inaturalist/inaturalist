import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ProjectFormContainer from "../containers/project_form_container";

const App = ( { form, createNewProject } ) => {
  if ( form.project ) {
    return ( <ProjectFormContainer /> );
  }
  return (
    <div id="ProjectsForm">
      <Grid className="intro">
        <Row>
          <Col xs={12}>
            <h1>Welcome to projects!</h1>
          </Col>
        </Row>
        <Row>
          <Col xs={6}>
            <h2>Regular</h2>
            <div className="type-icon">
              <i className="fa fa-object-ungroup" />
            </div>
            <div>
              A project allows you to gather and visualize observations using the core iNaturalist
              search tools. This eliminates the need to manually add observations because everything
              that meets the parameters set by the project will be automatically included.
            </div>
            <ul>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Data visualizations
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Leaderboards among individuals
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Can be included in multiple umbrella projects
                </div>
              </li>
            </ul>
          </Col>
          <Col xs={6}>
            <h2>Umbrella</h2>
            <div className="type-icon">
              <i className="fa fa-object-group" />
            </div>
            <div>
              An umbrella project can be used to compare statistics across two or more Automatic or
              Traditional Projects. The other projects need to be created before you can create an
              umbrella project. You can include up to X projects under a single umbrella. Umbrella
              projects cannot contain other umbrella projects.
            </div>
            <ul>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Visual comparisons of data among projects under the umbrella
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Leaderboards among projects
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Click through to individual projects
                </div>
              </li>
            </ul>
          </Col>
        </Row>
        <Row>
          <Col xs={6}>
            <div className="btn-div">
              <button
                className="btn-green"
                onClick={ ( ) => createNewProject( "collection" ) }
              >
                Get started
              </button>
            </div>
          </Col>
          <Col xs={6}>
            <div className="btn-div">
              <button
                className="btn-green"
                onClick={ ( ) => createNewProject( "umbrella" ) }
              >
                Get started
              </button>
            </div>
          </Col>
        </Row>
        <Row>
          <Col xs={12}>
            <p className="contact">
              Do you need features from traditional projects, such as access to true coordinates,
              custom observation fields, or adding individual observations that can’t be
              automatically filtered? Contact us at <a href="mailto:help@inaturalist.org">
                help@inaturalist.org
              </a>.
            </p>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

App.propTypes = {
  form: PropTypes.object,
  createNewProject: PropTypes.func
};

export default App;
