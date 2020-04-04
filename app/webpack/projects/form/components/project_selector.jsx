import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Overlay, Popover } from "react-bootstrap";
import ProjectAutocomplete from "../../../observations/identify/components/project_autocomplete";

class ProjectSelector extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.projectAutocomplete = React.createRef( );
  }

  render( ) {
    const {
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse
      ? I18n.t( "exclude_projects" )
      : I18n.t( "include_projects" );
    const rule = inverse ? "not_in_project?" : "in_project?";
    const rulesAttribute = inverse ? "notProjectRules" : "projectRules";
    const notTypes = ["umbrella"];
    if ( project.project_type !== "umbrella" ) {
      notTypes.push( "collection" );
    }
    const sortedSubprojects = _.sortBy( project[rulesAttribute],
      r => _.toLower( r.project.title ) );
    return (
      <div className="ProjectSelector">
        <label>{ label }</label>
        <div className={`form-group ${project.errors.subprojects && "has-error"}`}>
          <div className="input-group">
            <span className="input-group-addon fa fa-briefcase" />
            <ProjectAutocomplete
              ref={this.projectAutocomplete}
              key={_.map( project[rulesAttribute], r => r.project.id ).join( "," )}
              afterSelect={e => {
                addProjectRule( rule, "Project", e.item );
                this.projectAutocomplete.current.inputElement( ).val( "" );
              }}
              notIDs={_.map( project[rulesAttribute], r => r.project.id )}
              notTypes={notTypes}
              bootstrapClear
              disabled={!_.isEmpty( project.errors.subprojects )}
            />
          </div>
          { project.errors.subprojects && (
            <Overlay
              show
              placement="top"
              target={( ) => this.projectAutocomplete.current}
            >
              <Popover
                id="popover-title"
                className="popover-error"
              >
                { project.errors.subprojects }
              </Popover>
            </Overlay>
          ) }
        </div>
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( sortedSubprojects, projectRule => (
              <div className="badge-div" key={`project_rule_${projectRule.project.id}`}>
                <span className="badge">
                  { projectRule.project.title }
                  <button
                    type="button"
                    className="btn btn-nostyle"
                    onClick={( ) => removeProjectRule( projectRule )}
                  >
                    <i className="fa fa-times-circle-o" />
                  </button>
                </span>
              </div>
            ) ) }
          </div>
        ) }
      </div>
    );
  }
}

ProjectSelector.propTypes = {
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func,
  inverse: PropTypes.bool
};

export default ProjectSelector;
