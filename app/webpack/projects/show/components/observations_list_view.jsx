import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import InfiniteScroll from "react-infinite-scroller";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";
import FormattedDate from "../../shared/formatted_date";
import ViewMoreFooter from "./view_more_footer";

const ObservationsListView = ( {
  config, observations, hasMore, loadMore, setObservationFilters, showViewMoreLink, viewMoreUrl
} ) => {
  const scrollIndex = config.observationsScrollIndex || 30;
  const filters = config.observationFilters;
  const loader = ( <div key="observations-list-view-loading" className="loading_spinner huge" /> );
  const sortColumn = ( filters.order_by === "observed_on" ) ? "observed" : "created";
  const observedCaretDirection = ( sortColumn === "observed" && filters.order === "asc" )
    ? "up"
    : "down";
  const createdCaretDirection = ( sortColumn === "created" && filters.order === "asc" )
    ? "up"
    : "down";
  return (
    <div className="ObservationsListView">
      <Grid>
        <Row>
          <Col xs={12}>
            <InfiniteScroll
              loadMore={loadMore}
              hasMore={hasMore}
              loader={loader}
            >
              <table className="ObservationsList" key="observations-list-view-list">
                <thead>
                  <tr>
                    <th>{ I18n.t( "media" ) }</th>
                    <th>{ I18n.t( "name" ) }</th>
                    <th>{ I18n.t( "user" ) }</th>
                    <th
                      className={`clicky ${sortColumn === "observed" && "sorting"}`}
                      onClick={( ) => setObservationFilters( {
                        order_by: "observed_on",
                        order: ( sortColumn === "observed" && filters.order === "desc" )
                          ? "asc"
                          : "desc"
                      } )}
                    >
                      { I18n.t( "observed" ) }
                      <i className={`fa fa-caret-${observedCaretDirection}`} />
                    </th>
                    <th>{ I18n.t( "place" ) }</th>
                    <th
                      className={`clicky ${sortColumn === "created" && "sorting"}`}
                      onClick={( ) => setObservationFilters( {
                        order_by: "created_at",
                        order: ( sortColumn === "created" && filters.order === "desc" )
                          ? "asc"
                          : "desc"
                      } )}
                    >
                      { I18n.t( "added" ) }
                      <i className={`fa fa-caret-${createdCaretDirection}`} />
                    </th>
                  </tr>
                </thead>
                <tbody>
                  { _.map( observations.slice( 0, scrollIndex ), ( o, index ) => {
                    const iconicTaxonName = o.taxon && o.taxon.iconic_taxon_name
                      ? o.taxon.iconic_taxon_name.toLowerCase( )
                      : "unknown";
                    let displayPlace;
                    if ( o.place_guess ) {
                      displayPlace = o.place_guess;
                    } else if ( o.latitude ) {
                      displayPlace = [o.latitude, o.longitude].join( "," );
                    } else {
                      displayPlace = I18n.t( "unknown" );
                    }
                    const identificationsCount = _.size( _.filter( o.identifications, "current" ) );
                    return (
                      <tr className={index % 2 === 0 ? "even" : ""} key={`obs_list_row_${o.id}`}>
                        <td className="photo">
                          <a
                            href={`/observations/${o.id}`}
                            style={o.photo( ) ? {
                              backgroundImage: `url( '${o.photo( "square" )}' )`
                            } : null}
                            target="_self"
                            className={
                              `${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`
                            }
                          >
                            { o.hasSounds( ) && <i className="sound-icon fa fa-volume-up" /> }
                            <i className={`taxon-image icon icon-iconic-${iconicTaxonName}`} />
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
                              taxon={o.taxon}
                              url={`/observations/${o.id}`}
                              user={config.currentUser}
                            />
                            <div className="meta">
                              { o.quality_grade === "research" && (
                                <span className="quality_grade research">
                                  { I18n.t( "research_grade" ) }
                                </span>
                              ) }
                              { identificationsCount > 0 && (
                                <span
                                  className="count identifications"
                                  title={
                                    I18n.t( "x_identifications", { count: identificationsCount } )
                                  }
                                >
                                  <i className="icon-identification" />
                                  { identificationsCount }
                                </span>
                              ) }
                              { o.comments.length > 0 && (
                                <span
                                  className="count comments"
                                  title={I18n.t( "x_comments", { count: o.comments.length } )}
                                >
                                  <i className="icon-chatbubble" />
                                  { o.comments.length }
                                </span>
                              ) }
                              { o.faves.length > 0 && (
                                <span
                                  className="count favorites"
                                  title={I18n.t( "x_faves", { count: o.faves.length } )}
                                >
                                  <i className="fa fa-star" />
                                  { o.faves.length }
                                </span>
                              ) }
                            </div>
                          </div>
                        </td>
                        <td className="user">
                          <UserImage user={o.user} />
                          <UserLink user={o.user} />
                        </td>
                        <td className={`date ${sortColumn === "observed" && "sorting"}`}>
                          <FormattedDate
                            date={o.observed_on_details && o.observed_on_details.date}
                            time={o.time_observed_at}
                            timezone={o.observed_time_zone}
                          />
                        </td>
                        <td className="place">
                          <i className="fa fa-map-marker" />
                          { displayPlace }
                        </td>
                        <td className={`date ${sortColumn === "created" && "sorting"}`}>
                          <FormattedDate
                            date={o.created_at_details.date}
                            time={o.created_at}
                            timezone={o.created_time_zone}
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
      <ViewMoreFooter
          showViewMoreLink={showViewMoreLink}
          viewMoreUrl={viewMoreUrl}
      />
    </div>
  );
};

ObservationsListView.propTypes = {
  config: PropTypes.object,
  setObservationFilters: PropTypes.func,
  hasMore: PropTypes.bool,
  loadMore: PropTypes.func,
  observations: PropTypes.array,
  showViewMoreLink: PropTypes.bool,
  viewMoreUrl: PropTypes.string
};

export default ObservationsListView;
