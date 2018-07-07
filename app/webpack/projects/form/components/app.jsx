import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import ProjectFormContainer from "../containers/project_form_container";

const App = ( { form, createNewProject } ) => {
  if ( form.project ) {
    return ( <ProjectFormContainer /> );
  }
  return (
    <div id="ProjectsForm">
      <Grid>
        <Row className="intro-row">
          <Col xs={6}>
            <h1>{ I18n.t( "views.projects.new.welcome_to_projects" ) }</h1>
            <div className="intro">{ I18n.t( "views.projects.new.we_have_redesigned_projects" ) }</div>
            <ul>
              <li>
                <i className="fa fa-file-image-o" />
                <div>{ I18n.t( "views.projects.new.custom_banner_icon_and_project_description" ) }</div>
              </li>
              <li>
                <i className="fa fa-link" />
                <div>{ I18n.t( "views.projects.new.unique_url_for_outreach" ) }</div>
              </li>
              <li>
                <i className="fa fa-bullhorn" />
                <div>{ I18n.t( "views.projects.new.users_can_follow_your_project" ) }</div>
              </li>
              <li>
                <i className="fa fa-users" />
                <div>{ I18n.t( "views.projects.new.multiple_project_administrators" ) }</div>
              </li>
              <li>
                <i className="fa fa-gears" />
                <div>{ I18n.t( "views.projects.new.no_need_to_rely_on_manual_addition" ) }</div>
              </li>
            </ul>
          </Col>
          <Col xs={6}>
            <img src={ HERO_IMAGE_PATH } className="preview-img" />
          </Col>
        </Row>
        <Row>
          <Col xs={12}>
            <div className="separator" />
          </Col>
        </Row>
        <Row className="types-row">
          <Col xs={6}>
            <h2>{ I18n.t( "views.projects.new.collection_projects" ) }</h2>
            <div>{ I18n.t( "views.projects.new.a_project_allows_you_to_gather" ) }</div>
            <h4>{ I18n.t( "views.projects.new.collection_project_features" ) }</h4>
            <ul>
              <li>
                <i className="fa fa-area-chart" />
                <div>{ I18n.t( "views.projects.new.data_visualizations" ) }</div>
              </li>
              <li>
                <i className="fa fa-trophy" />
                <div dangerouslySetInnerHTML={ { __html:
                  I18n.t( "views.projects.new.leaderboards_among_individuals" ) } }
                />
              </li>
              <li>
                <i className="fa fa-check" />
                <div>{ I18n.t( "views.projects.new.can_be_included_in_multiple" ) }</div>
              </li>
              <li>
                <i className="fa fa-clock-o" />
                <div>{ I18n.t( "views.projects.new.start_and_end_times_for_bioblitzes" ) }</div>
              </li>
            </ul>
          </Col>
          <Col xs={6}>
            <h2>{ I18n.t( "umbrella_projects" ) }</h2>
            <div>{ I18n.t( "views.projects.new.an_umbrella_project_can_be_used_to" ) }</div>
            <h4>{ I18n.t( "views.projects.new.umbrella_project_features" ) }</h4>
            <ul>
              <li>
                <i className="fa fa-pie-chart" />
                <div>{ I18n.t( "views.projects.new.visual_comparison_of_data_among" ) }</div>
              </li>
              <li>
                <i className="fa fa-trophy" />
                <div dangerouslySetInnerHTML={ { __html:
                  I18n.t( "views.projects.new.leaderboards_among_projects_and_bioblitzes" ) } }
                />
              </li>
              <li>
                <i className="fa fa-external-link-square" />
                <div>{ I18n.t( "views.projects.new.click_through_to_individual_projects" ) }</div>
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
                { I18n.t( "get_started" ) }
              </button>
              <a href="/projects/global-amphibian-bioblitz">
                <div className="view-sample">
                  <i className="fa fa-external-link" />
                { I18n.t( "view_sample" ) }
                </div>
              </a>
            </div>
          </Col>
          <Col xs={6}>
            <div className="btn-div">
              <button
                className="btn-green"
                onClick={ ( ) => createNewProject( "umbrella" ) }
              >
                { I18n.t( "get_started" ) }
              </button>
              <a href="/projects/city-nature-challenge-2018">
                <div className="view-sample">
                  <i className="fa fa-external-link" />
                  { I18n.t( "view_sample" ) }
                </div>
              </a>
            </div>
          </Col>
        </Row>
        <Row>
          <Col xs={8}>
            <p className="contact">
              { I18n.t( "views.projects.new.do_you_need_features_from_traditional" ) }
              <span dangerouslySetInnerHTML={ { __html:
                I18n.t( "views.projects.new.use_this_link_to_create_html", { url: "/projects/new_traditional" } ) } }
              />
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
