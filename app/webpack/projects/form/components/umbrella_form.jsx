import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ProjectAutocomplete from "../../../observations/identify/components/project_autocomplete";

class UmbrellaForm extends React.Component {
  render( ) {
    const {
      project,
      addProjectRule,
      removeProjectRule
    } = this.props;
    return (
      <div id="UmbrellaForm" className="Form">
        <Grid>
          <Row className="text">
            <Col xs={12}>
              <h2>Observation Requirements</h2>
              <div className="help-text">
                Please specify the requirements for the observations to be added to this project.
                You can have multiple species and places.
              </div>
            </Col>
          </Row>
          <Row className="first-row">
            <Col xs={4}>
              <label>Projects</label>
              <ProjectAutocomplete
                ref="ua"
                key={ _.map( project.projectRules, rule => rule.project.id ).join( "," ) }
                afterSelect={ e => {
                  addProjectRule( "in_project?", "Project", e.item );
                  this.refs.ua.inputElement( ).val( "" );
                } }
                notIDs={ _.map( project.projectRules, rule => rule.project.id ) }
                notTypes={ ["umbrella"] }
                bootstrapClear
              />
              { !_.isEmpty( project.projectRules ) && (
                <div className="icon-previews">
                  { _.map( project.projectRules, projectRule => (
                    <div className="badge-div" key={ `project_rule_${projectRule.project.id}` }>
                      <span className="badge">
                        { projectRule.project.title }
                        <i
                          className="fa fa-times-circle-o"
                          onClick={ ( ) => removeProjectRule( projectRule ) }
                        />
                      </span>
                    </div>
                  ) ) }
                </div>
              ) }
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}

UmbrellaForm.propTypes = {
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func
};

export default UmbrellaForm;
