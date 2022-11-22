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
                  <div
                    className="contents"
                    dangerouslySetInnerHTML={{
                      __html: I18n.t( "views.observations.show.quality_assessment_help2_html", {
                        site_name: SITE.short_name
                      } )
                    }}
                  />
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
              <InnerWrapper>
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
