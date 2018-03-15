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
