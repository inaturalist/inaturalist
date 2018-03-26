import _ from "lodash";
import React, { PropTypes } from "react";
import safeHtml from "safe-html";
import moment from "moment";

const News = ( { project } ) => {
  if ( !project.posts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  if ( _.isEmpty( project.posts ) ) { return ( <div /> ); }

  return (
    <div className="News">
      <h2>
        News
        <a href={ `/projects/${project.slug}/journal` }>
          <i className="fa fa-arrow-circle-right" />
        </a>
      </h2>
      <div className="posts">
        { _.map( project.posts.results, post => (
          <div className="post" key={ `post_${post.id}` }>
            <a href={ `/projects/${project.slug}/journal/${post.id}` }>
              <div className="date">{ moment( post.created_at ).format( "LL - LT" ) }</div>
              <div className="title">{ post.title }</div>
              <div className="body">
                { safeHtml( post.body, { allowedTags: [] } ).substring( 0, 80 ) }...
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
  );
};

News.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default News;
