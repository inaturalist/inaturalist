import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import moment from "moment";
import UserText from "../../../shared/components/user_text";

const UmbrellaNews = ( { project } ) => {
  if ( !project.posts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  const noNews = _.isEmpty( project.posts ) || _.isEmpty( project.posts.results );
  return (
    <Grid className="News">
      <Row>
        <Col xs={12}>
          <h2>
            { I18n.t( "news" ) }
            <a href={ `/projects/${project.slug}/journal` }>
              <i className="fa fa-arrow-circle-right" />
            </a>
          </h2>
        </Col>
      </Row>
      { noNews ?
        (
          <div className="empty-text">
            { I18n.t( "no_news_yet" ) }. { I18n.t( "check_back_soon" ) }
          </div>
        ) : (
          <div>
            <Row className="posts">
              { _.map( project.posts.results, post => (
                <Col xs={ 4 } className="post">
                  <a href={ `/projects/${project.slug}/journal/${post.id}` }>
                    <div className="date">{ moment( post.created_at ).format( "LL - LT" ) }</div>
                    <div className="title">{ post.title }</div>
                    <div className="body">
                      <UserText
                        text={ post.body }
                        truncate={ 120 }
                        moreToggle={ false }
                        stripWhitespace
                      />
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
          </div>
        )
      }
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
