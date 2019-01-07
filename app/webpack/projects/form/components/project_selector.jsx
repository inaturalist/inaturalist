import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ProjectAutocomplete from "../../../observations/identify/components/project_autocomplete";

class ProjectSelector extends React.Component {
  render( ) {
    const {
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse
      ? I18n.t( "exclude_x", { x: I18n.t( "projects" ) } )
      : I18n.t( "projects" );
    const rule = inverse ? "not_in_project?" : "in_project?";
    const rulesAttribute = inverse ? "notProjectRules" : "projectRules";
    const notTypes = ["umbrella"];
    if ( project.project_type !== "umbrella" ) {
      notTypes.push( "collection" );
    }
    return (
      <div className="ProjectSelector">
        <label>{ label }</label>
        <div className="input-group">
          <span className="input-group-addon fa fa-briefcase" />
          <ProjectAutocomplete
            ref="ua"
            key={ _.map( project[rulesAttribute], r => r.project.id ).join( "," ) }
            afterSelect={ e => {
              addProjectRule( rule, "Project", e.item );
              this.refs.ua.inputElement( ).val( "" );
            } }
            notIDs={ _.map( project[rulesAttribute], r => r.project.id ) }
            notTypes={ notTypes }
            bootstrapClear
          />
        </div>
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], projectRule => (
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
      </div>
    );
  }
}

ProjectSelector.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func,
  inverse: PropTypes.bool
};

export default ProjectSelector;
