// We use dangerouslySetInnerHTML a lot in this file
/* eslint-disable react/no-danger */
import React from "react";
import PropTypes from "prop-types";
import {
  Grid,
  Row,
  Col,
  Panel,
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import ResearchGradeProgressContainer from "../containers/research_grade_progress_container";
import QualityMetricsContainer from "../containers/quality_metrics_container";

class Assessment extends React.Component {
  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_quality_metrics : true
    };
  }

  render( ) {
    const {
      config,
      innerWrapper,
      observation,
      updateSession
    } = this.props;
    if ( !observation ) { return ( <span /> ); }
    const loggedIn = config && config.currentUser;
    const { open } = this.state;
    const InnerWrapper = innerWrapper || ( props => (
      <div>
        {
          // eslint-disable-next-line react/prop-types
          props.children
        }
      </div>
    ) );
    return (
      <Grid>
        <div className="QualityMetrics collapsible-section">
          <div>
            <h3 className="collapsible">
              <button
                type="button"
                className="btn btn-nostyle"
                onClick={( ) => {
                  if ( loggedIn ) {
                    updateSession( { prefers_hide_obs_show_quality_metrics: open } );
                  }
                  this.setState( { open: !open } );
                }}
              >
                <i className={`fa fa-chevron-circle-${open ? "down" : "right"}`} />
                { I18n.t( "data_quality_assessment" ) }
              </button>
            </h3>
            <OverlayTrigger
              trigger="click"
              rootClose
              placement="top"
              containerPadding={20}
              overlay={(
                <Popover
                  className="DataQualityOverlay PopoverWithHeader"
                  id="popover-data-quality"
                >
                  <div className="header">
                    { I18n.t( "data_quality_assessment" ) }
                  </div>
                  <div className="contents">
                    <p
                      dangerouslySetInnerHTML={{
                        __html: I18n.t( "views.observations.show.dqa_help_needs_id_lead_html" )
                      }}
                    />
                    <ul>
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_needs_id_has_a_date_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_needs_id_is_georeferenced_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_needs_id_has_photos_or_sounds_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_needs_id_is_not_of_human_html" )
                        }}
                      />
                    </ul>
                    <p
                      dangerouslySetInnerHTML={{
                        __html: I18n.t( "views.observations.show.dqa_help_research_grade_lead_html" )
                      }}
                    />
                    <ul>
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_research_grade_community_species_html", {
                            site_name: SITE.short_name
                          } )
                        }}
                      />
                    </ul>
                    <p
                      dangerouslySetInnerHTML={{
                        __html: I18n.t( "views.observations.show.dqa_help_casual_lead_html" )
                      }}
                    />
                    <ul>
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_day_year_not_accurate2_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_location_not_accurate_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_not_wild_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_not_organism_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_not_recent_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_not_one_subject_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_voted_out_html" )
                        }}
                      />
                      <li
                        dangerouslySetInnerHTML={{
                          __html: I18n.t( "views.observations.show.dqa_help_casual_opted_out_maverick_html" )
                        }}
                      />
                    </ul>
                    <p>{ I18n.t( "views.observations.show.dqa_help_system_lead" ) }</p>
                    <ul>
                      <li>{ I18n.t( "views.observations.show.dqa_help_system_captive_vote" ) }</li>
                    </ul>
                  </div>
                </Popover>
              )}
              className="cool"
            >
              <span className="popover-data-quality-link">
                <i className="fa fa-info-circle" />
              </span>
            </OverlayTrigger>
          </div>
          <Panel expanded={open} onToggle={() => {}}>
            <Panel.Collapse>
              <InnerWrapper config={config}>
                <Row>
                  <Col xs={7}>
                    <QualityMetricsContainer />
                  </Col>
                  <Col xs={5}>
                    <ResearchGradeProgressContainer />
                  </Col>
                </Row>
              </InnerWrapper>
            </Panel.Collapse>
          </Panel>
        </div>
      </Grid>
    );
  }
}

Assessment.propTypes = {
  config: PropTypes.object,
  innerWrapper: PropTypes.func,
  observation: PropTypes.object,
  updateSession: PropTypes.func
};

export default Assessment;
