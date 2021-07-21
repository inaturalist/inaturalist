import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import { numberWithCommas } from "../../../shared/util";
import UserLink from "../../../shared/components/user_link";
import UserImage from "../../../shared/components/user_image";
import InfiniteScroll from "react-infinite-scroller";

class IdentifiersTab extends Component {
  componentDidMount( ) {
    this.props.fetchIdentifiers( );
  }

  render( ) {
    const {
      identifiers,
      config,
      setConfig,
      project
    } = this.props;

    if ( !project.all_identifiers_loaded ) {
      return ( <div className="loading_spinner huge" /> );
    }
    if ( _.isEmpty( identifiers ) ) { return ( <span /> ); }
    const scrollIndex = config.identifiersScrollIndex || 30;
    const loader = ( <div key="identifiers-tab-loading" className="loading_spinner huge" /> );
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
                <table key="identifiers-tab-table">
                  <thead>
                    <tr>
                      <th className="rank">{ I18n.t( "rank" ) }</th>
                      <th>{ I18n.t( "user" ) }</th>
                      <th>{ I18n.t( "identifications" ) }</th>
                    </tr>
                  </thead>
                  <tbody>
                    { _.map( identifiers.slice( 0, scrollIndex ), ( i, index ) => (
                      <tr className={ index % 2 !== 0 ? "odd" : "" } key={ `identifier-${i.user.id}` }>
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
  }
}

IdentifiersTab.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  identifiers: PropTypes.array,
  fetchIdentifiers: PropTypes.func,
  project: PropTypes.object
};

export default IdentifiersTab;
