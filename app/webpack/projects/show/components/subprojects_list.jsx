import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

const SubprojectsList = ( { project } ) => (
  <div className="SubprojectsList">
    <h2>
      { I18n.t( "views.projects.projects_included" ) }
    </h2>
    <table>
      <tbody>
        { _.map( _.sortBy( project.projectRules, r => r.project.title ), rule => (
          <tr>
            <td>
              <a href={ `/projects/${rule.project.slug}` }>
                { !rule.project.icon || rule.project.icon.match( "attachment_defaults" ) ? (
                  <i className="fa fa-briefcase project-icon" />
                ) : (
                  <div
                    className="project-icon"
                    style={ { backgroundImage: `url( '${rule.project.icon}' )` } }
                  />
                ) }
              </a>
            </td>
            <td className="label-cell">
              <a href={ `/projects/${rule.project.slug}` }>
                { rule.project.title }
              </a>
            </td>
          </tr>
        ) ) }
      </tbody>
    </table>
  </div>
);

SubprojectsList.propTypes = {
  project: PropTypes.object
};

export default SubprojectsList;
