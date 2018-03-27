import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import InfiniteScroll from "react-infinite-scroller";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";
import FormattedDate from "../../shared/formatted_date";

const ObservationsListView = ( { config, observations, hasMore, loadMore } ) => {
  if ( _.isEmpty( observations ) ) { return ( <span /> ); }
  const scrollIndex = config.observationsScrollIndex || 30;
  const loader = ( <div className="loading_spinner huge" /> );
  return (
    <div className="ObservationsListView">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <InfiniteScroll
              loadMore={ loadMore }
              hasMore={ hasMore }
              loader={ loader }
            >
              <table className="ObservationsList">
                <thead>
                  <tr>
                    <th>Media</th>
                    <th>Name</th>
                    <th>User</th>
                    <th>Observed</th>
                    <th>Place</th>
                    <th>Added</th>
                  </tr>
                </thead>
                <tbody>
                  { _.map( observations.slice( 0, scrollIndex ), ( o, index ) => {
                    const iconicTaxonName = o.taxon && o.taxon.iconic_taxon_name ?
                      o.taxon.iconic_taxon_name.toLowerCase( ) : "unknown";
                    let displayPlace;
                    if ( o.place_guess ) {
                      displayPlace = o.place_guess;
                    } else if ( o.latitude ) {
                      displayPlace = [o.latitude, o.longitude].join( "," );
                    } else {
                      displayPlace = I18n.t( "unknown" );
                    }
                    return (
                      <tr className={ index % 2 !== 0 && "odd" } key={ `obs_list_row_${o.id}` }>
                        <td className="photo">
                          <a
                            href={`/observations/${o.id}`}
                            style={ o.photo( ) ? {
                              backgroundImage: `url( '${o.photo( "square" )}' )`
                            } : null }
                            target="_self"
                            className={
                              `${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`
                            }
                          >
                            <i className={ `taxon-image icon icon-iconic-${iconicTaxonName}`} />
                            { ( o.photos.length > 1 ) && (
                              <span className="photo-count">
                                { o.photos.length }
                              </span>
                            ) }
                          </a>
                        </td>
                        <td className="taxon">
                          <div className="contents">
                            <SplitTaxon
                              taxon={ o.taxon }
                              url={ `/observations/${o.id}` }
                              user={ config.currentUser }
                            />
                            <div className="meta">
                              { o.quality_grade === "research" && (
                                <span className="quality_grade research">
                                  { I18n.t( "research_grade" ) }
                                </span>
                              ) }
                              { o.non_owner_ids.length > 0 && (
                                <span
                                  className="count identifications"
                                  title={
                                    I18n.t( "x_identifications", { count: o.non_owner_ids.length } )
                                  }
                                >
                                  <i className="icon-identification" />
                                  { o.non_owner_ids.length }
                                </span>
                              ) }
                              { o.comments.length > 0 && (
                                <span
                                  className="count comments"
                                  title={ I18n.t( "x_comments", { count: o.comments.length } ) }
                                >
                                  <i className="icon-chatbubble" />
                                  { o.comments.length }
                                </span>
                              ) }
                              { o.faves.length > 0 && (
                                <span
                                  className="count favorites"
                                  title={ I18n.t( "x_faves", { count: o.faves.length } ) }
                                >
                                  <i className="fa fa-star" />
                                  { o.faves.length }
                                </span>
                              ) }
                            </div>
                          </div>
                        </td>
                        <td className="user">
                          <UserImage user={ o.user } />
                          <UserLink user={ o.user } />
                        </td>
                        <td className="date">
                          <FormattedDate
                            date={ o.observed_on_details.date }
                            time={ o.time_observed_at }
                            timezone={ o.observed_time_zone }
                          />
                        </td>
                        <td className="place">
                          <i className="fa fa-map-marker" />
                          { displayPlace }
                        </td>
                        <td className="date">
                          <FormattedDate
                            date={ o.created_at_details.date }
                            time={ o.created_at }
                            timezone={ o.created_time_zone }
                          />
                        </td>
                      </tr>
                    );
                  } )
                 }
                </tbody>
              </table>
            </InfiniteScroll>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

ObservationsListView.propTypes = {
  config: PropTypes.object,
  setConfig: PropTypes.func,
  hasMore: PropTypes.bool,
  infiniteScrollObservations: PropTypes.func,
  loadMore: PropTypes.func,
  observations: PropTypes.array
};

export default ObservationsListView;
