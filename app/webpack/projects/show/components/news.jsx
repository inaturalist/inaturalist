import _ from "lodash";
import React, { PropTypes } from "react";
import moment from "moment";
import UserText from "../../../shared/components/user_text";

const News = ( { project } ) => {
  if ( !project.posts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  const noNews = _.isEmpty( project.posts ) || _.isEmpty( project.posts.results );
  return (
    <div className="News">
      <h2>
        { I18n.t( "news" ) }
        <a href={ `/projects/${project.slug}/journal` }>
          <i className="fa fa-arrow-circle-right" />
        </a>
      </h2>
      { noNews ?
        (
          <div className="empty-text">
            { I18n.t( "no_news_yet" ) }. { I18n.t( "check_back_soon" ) }
          </div>
        ) : (
          <div>
            <div className="posts">
              { _.map( project.posts.results, post => (
                <div className="post" key={ `post_${post.id}` }>
                  <a href={ `/projects/${project.slug}/journal/${post.id}` }>
                    <div className="date">{ moment( post.created_at ).format( "LL - LT" ) }</div>
                    <div className="title">{ post.title }</div>
                    <div className="body">
                      <UserText
                        text={ post.body }
                        truncate={ 120 }
                        moreToggle={ false }
                      />
                    </div>
                  </a>
                </div>
              ) ) }
            </div>
            <a href={ `/projects/${project.slug}/journal` }>
              <button className="btn-green" >
                { I18n.t( "view_all" ) }
              </button>
            </a>
          </div>
        )
      }
    </div>
  );
};

News.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default News;
