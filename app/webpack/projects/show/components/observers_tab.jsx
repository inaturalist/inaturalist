import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import { numberWithCommas } from "../../../shared/util";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";
import InfiniteScroll from "react-infinite-scroller";

const ObserversTab = ( { config, observers, setConfig } ) => {
  if ( _.isEmpty( observers ) ) { return ( <span /> ); }
  const scrollIndex = config.observersScrollIndex || 30;
  const loader = ( <div className="loading_spinner huge" /> );
  return (
    <div className="Observers">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <InfiniteScroll
              loadMore={ ( ) => { setConfig( { observersScrollIndex: scrollIndex + 30 } ); } }
              hasMore={ observers.length >= scrollIndex }
              loader={loader}
            >
            <table>
                <thead>
                  <tr>
                    <th className="rank">Rank</th>
                    <th>User</th>
                    <th
                      className="clicky"
                      onClick={ ( ) => setConfig( { observersSort: "observations" } ) }
                    >
                      Observations
                      <i className="fa fa-caret-down" />
                    </th>
                    <th
                      className="clicky"
                      onClick={ ( ) => setConfig( { observersSort: "species" } ) }
                    >
                      Species
                      <i className="fa fa-caret-down" />
                    </th>
                  </tr>
                </thead>
                <tbody>
                  { _.map( observers.slice( 0, scrollIndex ), ( i, index ) => (
                    <tr className={ index % 2 !== 0 && "odd" } key={ `observer-${i.user.id}` }>
                      <td className="rank">{ index + 1 }</td>
                      <td>
                        <UserImage user={ i.user } />
                        <UserLink user={ i.user } />
                      </td>
                      <td className={`count ${config.observersSort !== "species" && "sorted"}`}>
                        { numberWithCommas( i.observation_count ) }
                      </td>
                      <td className={`count ${config.observersSort === "species" && "sorted"}`}>
                        { numberWithCommas( i.species_count ) }
                      </td>
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

ObserversTab.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  observers: PropTypes.array
};

export default ObserversTab;
