import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

class CodeContributor extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      expanded: false
    };
    this.showAllPullRequests = this.showAllPullRequests.bind( this );
    this.showFewerPullRequests = this.showFewerPullRequests.bind( this );
  }

  showAllPullRequests( ) {
    this.setState( { expanded: true } );
  }

  showFewerPullRequests( ) {
    this.setState( { expanded: false } );
  }

  render( ) {
    const { userData } = this.props;
    const { expanded } = this.state;
    const pullRequestsToDisplay = expanded
      ? userData.pullRequests
      : _.slice( userData.pullRequests, 0, 5 );
    const morePullRequestsToShow = pullRequestsToDisplay.length < userData.pullRequests.length;
    return (
      <div className="CodeContribitor stacked flex-row">
        <div className="text-center">
          <a
            className="userimage UserImage stacked"
            href={userData.user.html_url}
            style={{
              backgroundImage: `url('${userData.user.avatar_url}')`
            }}
          >
            { " " }
          </a>
        </div>
        <div>
          <h4><a href={userData.user.html_url}><span>{ userData.user.login }</span></a></h4>
          <ul>
            { pullRequestsToDisplay.map( pr => (
              <li key={pr.html_url}>
                <a href={pr.html_url}>{ pr.title.replace( /^[^A-z]+/, "" ) }</a>
              </li>
            ) ) }
          </ul>
          { morePullRequestsToShow && (
            <div className="controls text-center stacked">
              <button
                type="button"
                className="btn btn-sm btn-dark"
                onClick={this.showAllPullRequests}
              >
                { I18n.t( "show_more" ) }
              </button>
            </div>
          )}
          { expanded && (
            <div className="controls text-center stacked">
              <button
                type="button"
                className="btn btn-sm btn-dark"
                onClick={this.showFewerPullRequests}
              >
                { I18n.t( "show_less" ) }
              </button>
            </div>
          )}
        </div>
      </div>
    );
  }
}

CodeContributor.propTypes = {
  userData: PropTypes.object
};

export default CodeContributor;
