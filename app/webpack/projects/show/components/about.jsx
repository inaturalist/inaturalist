import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import moment from "moment";
import Requirements from "./requirements";
import SubprojectsList from "./subprojects_list";
import UserText from "../../../shared/components/user_text";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";
import FeatureButtonContainer from "../containers/feature_button_container";

const About = ( {
  project,
  setSelectedTab,
  config
} ) => {
  const loggedIn = config.currentUser;
  const userIsAdmin = loggedIn && config.currentUser.roles
    && config.currentUser.roles.indexOf( "admin" ) >= 0;
  const userIsSiteAdmin = loggedIn && config.currentUser.site_admin;
  let siteAdminTools;
  if ( userIsAdmin || userIsSiteAdmin ) {
    siteAdminTools = (
      <div className="admin-tools">
        <h4>{ I18n.t( "site_admin_tools" ) }</h4>
        <FeatureButtonContainer />
      </div>
    );
  }
  return (
    <div className="About">
      <Grid>
        <Row>
          <Col xs={12}>
            <button
              type="button"
              className="back btn btn-nostyle linky"
              onClick={() => setSelectedTab( project.is_umbrella ? "umbrella_overview" : "overview" )}
            >
              <i className="fa fa-angle-left" />
              { I18n.t( "back_to_x", { noun: project.title } ) }
            </button>
          </Col>
        </Row>
        <Row>
          <Col xs={7}>
            <h1>{ project.title }</h1>
            <UserText text={project.description} className="body" />
            <div className="attribution">
              <span className="owner">
                <span className="type">
                  { I18n.t( "label_colon", { label: I18n.t( "created_by" ) } )}
                </span>
                <UserImage user={project.user} />
                <UserLink user={project.user} />
                { " " }
                <span className="date">
                  { "- " }
                  { moment( project.created_at ).format( "MMMM D, YYYY" ) }
                </span>
              </span>
              <table className="admins">
                <tbody>
                  <tr>
                    <td>
                      <span className="type">
                        {
                          I18n.t( "label_colon", {
                            label: I18n.t( "project_admins", { count: project.admins.length } )
                          } )
                        }
                      </span>
                    </td>
                    <td>
                      <div>
                        { _.map( project.admins, a => (
                          <span className="project-admin" key={`project-admins-${a.id}`}>
                            <span className="project-admin-span">
                              <UserImage user={a.user} />
                              <UserLink user={a.user} />
                            </span>
                          </span>
                        ) ) }
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </Col>
          <Col xs={5} className="requirements-col">
            { project.is_umbrella
              ? ( <SubprojectsList {...{ project, setSelectedTab, config }} /> )
              : ( <Requirements {...{ project, setSelectedTab, config }} /> )
            }
            { siteAdminTools }
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

About.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default About;
