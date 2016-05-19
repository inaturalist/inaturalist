import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import inflection from "lodash-inflection";
_.mixin( inflection );
import UserImage from "./user_image";

const IdentifierStats = ( {
  loading,
  users
} ) => {
  let content;
  if ( loading ) {
    content = (
      <div className="text-center text-muted">
        <i className="fa fa-refresh fa-spin"></i> { I18n.t( "loading" ) }
      </div>
    );
  } else if ( users.length === 0 ) {
    content = <div className="text-center text-muted">{ I18n.t( "no_matching_users" ) }</div>;
  } else {
    const mid = Math.ceil( users.length / 2 );
    const col1 = users.slice( 0, mid );
    const col2 = users.slice( mid, users.length );
    content = (
      <Row>
        <Col xs="6">
          <ol>
            {col1.map( ( item, i ) => (
              <li
                key={`identifier-${item.user.id}`}
              >
                <span className="position">{ _.ordinalize( i + 1 ) }</span>
                <UserImage user={ item.user } />
                <div className="details">
                  <a href={ `/people/${item.user.login}` }>{ item.user.login }</a>
                  { I18n.t( "x_ids", { count: item.count } ) }
                </div>
              </li>
            ) ) }
          </ol>
        </Col>
        <Col xs="6">
          <ol>
            {col2.map( ( item, i ) => (
              <li
                key={`identifier-${item.user.id}`}
              >
                <span className="position">{ _.ordinalize( i + mid + 1 ) }</span>
                <UserImage user={ item.user } />
                <div className="details">
                  <a href={ `/people/${item.user.login}` }>{ item.user.login }</a>
                  { I18n.t( "x_ids", { count: item.count } ) }
                </div>
              </li>
            ) ) }
          </ol>
        </Col>
      </Row>
    );
  }
  return (
    <div className="IdentifierStats">
      <h4>Leaderboard for Current Filters</h4>
      { content }
    </div>
  );
};

IdentifierStats.propTypes = {
  loading: PropTypes.bool,
  users: PropTypes.array
};

export default IdentifierStats;
