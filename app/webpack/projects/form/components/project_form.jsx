import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import RegularForm from "./regular_form";
import UmbrellaForm from "./umbrella_form";
import SharedForm from "./shared_form";

class ProjectForm extends React.Component {
  render( ) {
    const { project, submitProject } = this.props;
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
              <button
                className="btn-green"
                onClick={ ( ) => submitProject( ) }
                disabled={ project.saving }
              >{ project.saving ? "Saving..." : "Done" }</button>
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}

ProjectForm.propTypes = {
  project: PropTypes.object,
  submitProject: PropTypes.func
};

export default ProjectForm;
