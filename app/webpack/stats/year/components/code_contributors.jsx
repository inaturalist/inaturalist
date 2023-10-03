import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { Row, Col } from "react-bootstrap";

const CodeContributors = ( { data } ) => {
  const pullRequestsByUser = {};
  data.forEach( pr => {
    pullRequestsByUser[pr.user.login] = pullRequestsByUser[pr.user.login] || [];
    pullRequestsByUser[pr.user.login].push( pr );
  } );
  const dataByUser = _.sortBy(
    _.map( pullRequestsByUser, pullRequests => ( {
      user: pullRequests[0].user,
      pullRequests
    } ) ),
    d => d.user.login
  );
  const numCols = 3;

  return (
    <div className="CodeContributors">
      <Row>
        <Col xs={12}>
          <h3>
            <a name="code" href="#code">
              <span>{ I18n.t( "code_contributors" ) }</span>
            </a>
          </h3>
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t( "yir_code_contributors_desc_html", {
                url: "https://github.com/inaturalist"
              } )
            }}
          />
        </Col>
      </Row>
      { _.chunk( dataByUser, numCols ).map( row => (
        <Row key={`code-contributors-${row.map( d => d.user.login ).join( "-" )}`}>
          { row.map( d => (
            <Col xs={12} sm={12 / numCols} key={`code-contributors-${d.user.login}`}>
              <div className="CodeContribitor stacked flex-row">
                <div className="text-center">
                  <a
                    className="userimage UserImage stacked"
                    href={d.user.html_url}
                    style={{
                      backgroundImage: `url('${d.user.avatar_url}')`
                    }}
                  >
                    { " " }
                  </a>
                </div>
                <div>
                  <h4><a href={d.user.html_url}><span>{ d.user.login }</span></a></h4>
                  <ul>
                    { d.pullRequests.map( pr => (
                      <li key={pr.html_url}>
                        <a href={pr.html_url}>{ pr.title }</a>
                      </li>
                    ) ) }
                  </ul>
                </div>
              </div>
            </Col>
          ) ) }
        </Row>
      ) ) }
    </div>
  );
};

CodeContributors.propTypes = {
  data: PropTypes.array
};

export default CodeContributors;
