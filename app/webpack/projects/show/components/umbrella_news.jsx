import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import safeHtml from "safe-html";
import moment from "moment";

const UmbrellaNews = ( { project } ) => {
  if ( !project.posts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  if ( _.isEmpty( project.posts ) ) { return ( <div /> ); }

  return (
    <Grid className="News">
      <Row>
        <Col xs={12}>
          <h2>
            News
            <a href={ `/projects/${project.slug}/journal` }>
              <i className="fa fa-arrow-circle-right" />
            </a>
          </h2>
        </Col>
      </Row>
      <Row className="posts">
        { _.map( project.posts.results, post => (
          <Col xs={ 4 } className="post">
            <a href={ `/projects/${project.slug}/journal/${post.id}` }>
              <div className="date">{ moment( post.created_at ).format( "LL - LT" ) }</div>
              <div className="title">{ post.title }</div>
              <div className="body">
                { safeHtml( post.body, { allowedTags: [] } ).substring( 0, 80 ) }...
              </div>
            </a>
          </Col>
        ) ) }
      </Row>
      <Row>
        <Col xs={12}>
          <a href={ `/projects/${project.slug}/journal` }>
            <button className="btn-green" >
              { I18n.t( "view_all" ) }
            </button>
          </a>
        </Col>
      </Row>
    </Grid>
  );
};

UmbrellaNews.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default UmbrellaNews;
