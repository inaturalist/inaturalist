import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import moment from "moment";
import Requirements from "./requirements";
import UserText from "../../../shared/components/user_text";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";

class About extends React.Component {
  render( ) {
    const { project, setSelectedTab } = this.props;
    return (
      <div className="About">
        <Grid>
          <Row>
            <Col xs={ 12 }>
              <div
                className="back linky"
                onClick={ () => setSelectedTab( project.is_umbrella ? "umbrella_overview" : "overview" ) }
              >
                <i className="fa fa-angle-left" />
                Back to project
              </div>
            </Col>
          </Row>
          <Row>
            <Col xs={ 7 }>
              <h1>{ project.title }</h1>
              <UserText text={ project.description } className="body" />
              <div className="owner">
                <UserImage user={ project.user } />
                Created by:
                <UserLink user={ project.user } />
                <span className="date">
                  - { moment( project.created_at ).format( "MMMM D, YYYY" ) }
                </span>
              </div>
            </Col>
            <Col xs={ 5 } className="requirements-col">
              <h2>Project Requirements</h2>
              <div className="section-intro">
                Observations in this project must meet the following criteria:
              </div>
              <Requirements { ...this.props } />
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
};

About.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  setSelectedTab: PropTypes.func
};

export default About;
