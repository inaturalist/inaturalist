import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment";
import UserText from "../../../shared/components/user_text";

import HeaderWithMoreLink from "./header_with_more_link";

const News = ( { project } ) => {
  if ( !project.posts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  const noNews = _.isEmpty( project.posts ) || _.isEmpty( project.posts.results );
  return (
    <div className="News">
      <HeaderWithMoreLink href={`/projects/${project.slug}/journal`}>
        { I18n.t( "journal" ) }
      </HeaderWithMoreLink>
      { noNews ? (
        <div className="empty-text">
          { I18n.t( "no_journal_posts_yet" ) }
        </div>
      ) : (
        <div>
          <div className="posts">
            { _.map( project.posts.results, post => (
              <div className="post" key={`post_${post.id}`}>
                <a href={`/projects/${project.slug}/journal/${post.id}`}>
                  <div className="date">{ moment( post.published_at ).format( "LL - LT" ) }</div>
                  <div className="title">{ post.title }</div>
                  <div className="body">
                    <UserText
                      text={post.body}
                      truncate={120}
                      moreToggle={false}
                      stripTags
                      stripWhitespace
                    />
                  </div>
                </a>
              </div>
            ) ) }
          </div>
          <a href={`/projects/${project.slug}/journal`}>
            <button className="btn-green" type="button">
              { I18n.t( "view_all" ) }
            </button>
          </a>
        </div>
      ) }
    </div>
  );
};

News.propTypes = {
  project: PropTypes.object
};

export default News;
