import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import InfiniteScroll from "react-infinite-scroller";
import { numberWithCommas } from "../../../shared/util";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";

class ObserversTab extends Component {
  componentDidMount( ) {
    this.props.fetchObservers( );
  }

  render( ) {
    const {
      project,
      config,
      observers,
      setConfig,
      setObserversSort
    } = this.props;

    if ( !project.all_observers_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    if ( _.isEmpty( observers ) ) { return ( <span /> ); }
    const scrollIndex = config.observersScrollIndex || 30;
    const loader = ( <div key="observers-tab-loading" className="loading_spinner huge" /> );
    return (
      <div className="Observers">
        <Grid>
          <Row>
            <Col xs={12}>
              <InfiniteScroll
                loadMore={( ) => { setConfig( { observersScrollIndex: scrollIndex + 30 } ); }}
                hasMore={observers.length >= scrollIndex}
                loader={loader}
              >
                <table key="observers-tab-table">
                  <thead>
                    <tr>
                      <th className="rank">{ I18n.t( "rank" ) }</th>
                      <th>{ I18n.t( "user" ) }</th>
                      <th
                        className="clicky"
                        onClick={( ) => setObserversSort( "observations" )}
                      >
                        { I18n.t( "observations" ) }
                        <i className="fa fa-caret-down" />
                      </th>
                      <th
                        className="clicky"
                        onClick={( ) => setObserversSort( "species" )}
                      >
                        { I18n.t( "species" ) }
                        <i className="fa fa-caret-down" />
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    { _.map( observers.slice( 0, scrollIndex ), ( i, index ) => (
                      <tr className={index % 2 !== 0 ? "odd" : ""} key={`observer-${i.user.id}`}>
                        <td className="rank">{ index + 1 }</td>
                        <td>
                          <UserImage user={i.user} />
                          <UserLink user={i.user} />
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
  }
}

ObserversTab.propTypes = {
  project: PropTypes.object,
  config: PropTypes.object,
  setConfig: PropTypes.func,
  setObserversSort: PropTypes.func,
  fetchObservers: PropTypes.func,
  observers: PropTypes.array
};

export default ObserversTab;
