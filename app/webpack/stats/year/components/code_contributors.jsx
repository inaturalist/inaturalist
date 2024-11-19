import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { Row, Col } from "react-bootstrap";
import CodeContributor from "./code_contributor";

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
              <CodeContributor userData={d} />
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
