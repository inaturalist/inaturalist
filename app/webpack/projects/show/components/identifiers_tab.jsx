import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import { numberWithCommas } from "../../../shared/util";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";
import InfiniteScroll from "react-infinite-scroller";

const IdentifiersTab = ( { identifiers, config, setConfig } ) => {
  if ( _.isEmpty( identifiers ) ) { return ( <span /> ); }
  const scrollIndex = config.identifiersScrollIndex || 30;
  const loader = ( <div className="loading_spinner huge" /> );
  return (
    <div className="Identifiers">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <InfiniteScroll
              loadMore={ ( ) => { setConfig( { identifiersScrollIndex: scrollIndex + 30 } ); } }
              hasMore={ identifiers.length >= scrollIndex }
              loader={ loader }
            >
              <table>
                <thead>
                  <tr>
                    <th className="rank">{ I18n.t( "rank" ) }</th>
                    <th>{ I18n.t( "user" ) }</th>
                    <th>{ I18n.t( "identifications" ) }</th>
                  </tr>
                </thead>
                <tbody>
                  { _.map( identifiers.slice( 0, scrollIndex ), ( i, index ) => (
                    <tr className={ index % 2 !== 0 && "odd" } key={ `identifier-${i.user.id}` }>
                      <td className="rank">{ index + 1 }</td>
                      <td>
                        <UserImage user={ i.user } />
                        <UserLink user={ i.user } />
                      </td>
                      <td className="count">{ numberWithCommas( i.count ) }</td>
                    </tr>
                  ) ) }
                </tbody>
              </table>
            </InfiniteScroll>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

IdentifiersTab.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  identifiers: PropTypes.array
};

export default IdentifiersTab;
