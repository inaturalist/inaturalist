import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col, Panel } from "react-bootstrap";
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
    const { observation, config } = this.props;
    if ( !observation ) { return ( <span /> ); }
    const loggedIn = config && config.currentUser;
    return (
      <Grid>
        <div className="QualityMetrics collapsible-section">
          <h3
            className="collapsible"
            onClick={ ( ) => {
              if ( loggedIn ) {
                this.props.updateSession( { prefers_hide_obs_show_quality_metrics: this.state.open } );
              }
              this.setState( { open: !this.state.open } );
            } }
          >
            <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
            { I18n.t( "data_quality_assessment" ) }
          </h3>
          <Panel collapsible expanded={ this.state.open }>
            <Row>
              <Col xs={7}>
                <QualityMetricsContainer />
              </Col>
              <Col xs={5}>
                <ResearchGradeProgressContainer />
              </Col>
            </Row>
          </Panel>
        </div>
      </Grid>
    );
  }
}

Assessment.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  updateSession: PropTypes.func
};

export default Assessment;
