import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ProjectFormContainer from "../containers/project_form_container";

const App = ( { form, setProject } ) => {
  if ( form.project ) {
    return ( <ProjectFormContainer /> );
  }
  return (
    <div id="ProjectsForm">
      <Grid>
        <Row>
          <Col xs={12}>
            <h1>Welcome to the new projects</h1>
          </Col>
        </Row>
        <Row className="intro">
          <Col xs={6}>
            <h2>Regular</h2>
            <div className="type-icon">
              <i className="fa fa-object-ungroup" />
            </div>
            <div>
              Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
              incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
              nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
            </div>
            <ul>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                </div>
              </li>
            </ul>
            <div className="btn-div">
              <button
                className="btn-green"
                onClick={ () => {
                  setProject( { project_type: "regular" } );
                  $( window ).scrollTop( 0 );
                } }
              >
                Get started
              </button>
            </div>
          </Col>
          <Col xs={6}>
            <h2>Umbrella</h2>
            <div className="type-icon">
              <i className="fa fa-object-group" />
            </div>
            <div>
              Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
              incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
              nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
            </div>
            <ul>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                </div>
              </li>
              <li>
                <i className="fa fa-square-o" />
                <div>
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
                </div>
              </li>
            </ul>
            <div className="btn-div">
              <button
                className="btn-green"
                onClick={ () => {
                  setProject( { project_type: "umbrella" } );
                  $( window ).scrollTop( 0 );
                } }
              >
                Get started
              </button>
            </div>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

App.propTypes = {
  config: PropTypes.object,
  form: PropTypes.object,
  setProject: PropTypes.func
};

export default App;
