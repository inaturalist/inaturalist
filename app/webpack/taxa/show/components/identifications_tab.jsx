import _ from "lodash";
import React, { Component } from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";
import {
  Col,
  Grid,
  Panel,
  Row,
  Dropdown,
  MenuItem
} from "react-bootstrap";
import moment from "moment-timezone";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import { taxonLayerForTaxon } from "../../shared/util";
import UserText from "../../../shared/components/user_text";
import UsersPopover from "../../../observations/show/components/users_popover";
import UserLink from "../../../shared/components/user_link";

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = {
  ...I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  ...shortRelativeTime
};
moment.locale( I18n.locale );
moment.updateLocale( moment.locale( ), { relativeTime } );

class IdentificationsTab extends Component {
  constructor( props, context ) {
    super( props, context );
    const allSorts = {
      votesDesc: {
        key: "votesDesc",
        label: "Highest to lowest votes",
        order_by: "votes",
        order: "desc"
      },
      votesAsc: {
        key: "votesAsc",
        label: "Lowest to higest votes",
        order_by: "votes",
        order: "asc"
      },
      newest: {
        key: "newest",
        label: "Newest to oldest",
        order_by: "created_at",
        order: "desc"
      },
      oldest: {
        key: "oldest",
        label: "Oldest to newest",
        order_by: "created_at",
        order: "asc"
      },
      lengthDesc: {
        key: "lengthDesc",
        label: "Longest to shortest",
        order_by: "word_count",
        order: "desc"
      }
    };
    const tabSorts = {
      upvoted: [
        allSorts.votesDesc,
        allSorts.votesAsc,
        allSorts.newest,
        allSorts.oldest
      ],
      downvoted: [
        allSorts.votesDesc,
        allSorts.votesAsc,
        allSorts.newest,
        allSorts.oldest
      ],
      "no-votes": [
        allSorts.newest,
        allSorts.oldest
      ],
      "not-nominated": [
        allSorts.newest,
        allSorts.oldest,
        allSorts.lengthDesc
      ]
    };
    this.state = {
      searchSearchTermPresent: null,
      allSorts,
      tabSorts
    };
  }

  setSearchSearchTermPresent( present ) {
    if ( this.state.searchSearchTermPresent === present ) {
      return;
    }

    this.setState( {
      searchSearchTermPresent: present
    } );
  }

  identificationPanel( result ) {
    const {
      config,
      identificationsQuery,
      setIdentificationsQuery,
      nominateIdentification,
      unnominateIdentification,
      voteIdentification,
      unvoteIdentification
    } = this.props;
    const annotations = (
      <div className="annotations">
        {result.identification.observation.annotations.map( annotation => (
          <button
            type="button"
            className={`btn btn-default btn-sm${identificationsQuery.term_value_id === annotation.controlled_value.id ? " active" : ""}`}
            key={annotation.uuid}
            onClick={( ) => {
              if ( identificationsQuery.term_value_id === annotation.controlled_value.id ) {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: null
                } );
              } else {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: annotation.controlled_value.id
                } );
              }
              $( "html, body" ).animate( {
                scrollTop: $( ".IdentificationsTab" ).offset( ).top
              }, 100 );
            }}
          >
            {annotation.controlled_attribute.label }
            :&nbsp;
            {annotation.controlled_value.label}
          </button>
        ) )}
      </div>
    );
    let img;
    if ( result.identification.observation.photos.length > 0 ) {
      const photo = result.identification.observation.photos[0];
      img = (
        <div
          className="image"
          style={{
            backgroundImage: `url('${photo.photoUrl( "medium" )}')`
          }}
        />
      );
    }
    const time = (
      <time
        className="time"
        dateTime={result.identification.created_at}
        title={moment( result.identification.created_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
      >
        <a
          href={`/identifications/${result.id}`}
        >
          {moment.parseZone( result.identification.created_at ).fromNow( )}
        </a>
      </time>
    );
    const votesFor = [];
    const votesAgainst = [];
    let userVotedFor;
    let userVotedAgainst;
    _.each( result.votes, v => {
      if ( v.vote_flag === true ) {
        votesFor.push( v );
      } else if ( v.vote_flag === false ) {
        votesAgainst.push( v );
      }
      if ( v.user?.id === config.currentUser.id ) {
        userVotedFor = ( v.vote_flag === true );
        userVotedAgainst = ( v.vote_flag === false );
      }
    } );
    const voteAction = () => (
      userVotedFor ? unvoteIdentification( result.id ) : voteIdentification( result.id )
    );
    const unvoteAction = () => (
      userVotedAgainst ? unvoteIdentification( result.id ) : voteIdentification( result.id, "bad" )
    );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";

    const nominationMenuItems = [];
    if ( result.nominated_by_user ) {
      nominationMenuItems.push( (
        <MenuItem
          key="id-unnominate"
          eventKey="unnominate"
        >
          Remove Nomination
        </MenuItem>
      ) );
    } else {
      nominationMenuItems.push( (
        <MenuItem
          key="id-nominate"
          eventKey="nominate"
        >
          Nominate
        </MenuItem>
      ) );
    }

    const userLink = (
      <UserLink
        className="user"
        config={config}
        noInativersary
        href={`/identifications/${result.identification.uuid}`}
        user={result.identification.user}
      />
    );

    return (
      <div
        key={`identification-${result.identification.uuid}`}
        className="Identification"
      >
        <div className="contents">
          <div className="preview">
            <a href={`/observations/${result.identification.observation.id}`}>
              {img}
            </a>
          </div>
          <div className="content">
            <Panel>
              <Panel.Heading>
                <Panel.Title>
                  <span
                    className="title-text"
                    // eslint-disable-next-line react/no-danger
                    dangerouslySetInnerHTML={{
                      __html: I18n.t( "user_suggested_an_id", {
                        user: ReactDOMServer.renderToString( userLink )
                      } )
                    }}
                  />
                  {time}
                  <div className="menu">
                    <span className="control-group">
                      <Dropdown
                        id="grouping-control"
                        onSelect={key => {
                          if ( key === "nominate" ) {
                            nominateIdentification( result.identification.uuid, result.id );
                          } else if ( key === "unnominate" ) {
                            unnominateIdentification( result.identification.uuid, result.id );
                          }
                        }}
                      >
                        <Dropdown.Toggle noCaret>
                          <i className="fa fa-chevron-down" />
                        </Dropdown.Toggle>
                        <Dropdown.Menu className="dropdown-menu-right">
                          { nominationMenuItems }
                        </Dropdown.Menu>
                      </Dropdown>
                    </span>
                  </div>
                </Panel.Title>
              </Panel.Heading>
              <Panel.Body>
                <div className="body">
                  <UserText text={result.identification.body} className="id_body" />
                </div>
                { result.nominated_by_user && (
                  <div className="votes">
                    <button
                      type="button"
                      className="btn btn-nostyle"
                      onClick={voteAction}
                      aria-label={I18n.t( "agree_" )}
                      title={I18n.t( "agree_" )}
                    >
                      <i className={`fa ${agreeClass}`} />
                    </button>
                    { !_.isEmpty( votesFor ) && (
                      <UsersPopover
                        users={_.map( votesFor, "user" )}
                        keyPrefix={`votes-against-${result.identification.uuid}`}
                        contents={(
                          <span>{votesFor.length === 0 ? null : votesFor.length}</span>
                        )}
                      />
                    ) }
                    <button
                      type="button"
                      onClick={unvoteAction}
                      className="btn btn-nostyle"
                      aria-label={I18n.t( "disagree_" )}
                      title={I18n.t( "disagree_" )}
                    >
                      <i className={`fa ${disagreeClass}`} />
                    </button>
                    { !_.isEmpty( votesAgainst ) && (
                      <UsersPopover
                        users={_.map( votesAgainst, "user" )}
                        keyPrefix={`votes-against-${result.identification.uuid}`}
                        contents={(
                          <span>{votesAgainst.length === 0 ? null : votesAgainst.length}</span>
                        )}
                      />
                    ) }
                  </div>
                ) }
              </Panel.Body>
              { result.nominated_by_user && (
                <Panel.Footer>
                  <span className="footer-text">
                    <UserLink
                      className="user"
                      config={config}
                      noInativersary
                      href={`/identifications/${result.identification.uuid}`}
                      user={result.nominated_by_user}
                    />
                    &nbsp;marked this as an ID tip
                  </span>
                  <time
                    className="time"
                    dateTime={result.nominated_at}
                    title={moment( result.nominated_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
                  >
                    {moment.parseZone( result.nominated_at ).fromNow( )}
                  </time>
                </Panel.Footer>
              ) }
            </Panel>
            <div className="annotations-conversation">
              {annotations}
              {result.identification.observation.discussion_count > 1 && (
                <div className="conversation">
                  <a href={`/observations/${result.identification.observation.id}`}>
                    View Full Conversation
                  </a>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }

  activeTab( ) {
    const {
      identificationsQuery
    } = this.props;
    let activeTab = "upvoted";
    if ( identificationsQuery.downvoted === "true" ) {
      activeTab = "downvoted";
    } else if ( identificationsQuery.upvoted === "false" && identificationsQuery.downvoted === "false" ) {
      activeTab = "no-votes";
    } else if ( identificationsQuery.nominated === "false" ) {
      activeTab = "not-nominated";
    }
    return activeTab;
  }

  identificationCategories( ) {
    const {
      identificationsQuery,
      setIdentificationsQuery
    } = this.props;
    const activeTab = this.activeTab( );
    return (
      <div className="btn-group identification-categories">
        <button
          type="button"
          className={`btn btn-default${activeTab === "upvoted" ? " active" : ""}`}
          onClick={( ) => {
            if ( activeTab === "upvoted" ) {
              return;
            }
            setIdentificationsQuery( {
              ...identificationsQuery,
              upvoted: "true",
              downvoted: null,
              nominated: "true",
              q: null,
              term_value_id: null,
              order_by: this.state.tabSorts.upvoted[0].order_by,
              order: this.state.tabSorts.upvoted[0].order,
              sortKey: this.state.tabSorts.upvoted[0].key
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          Upvoted
        </button>
        <button
          type="button"
          className={`btn btn-default${activeTab === "downvoted" ? " active" : ""}`}
          onClick={( ) => {
            if ( activeTab === "downvoted" ) {
              return;
            }
            setIdentificationsQuery( {
              ...identificationsQuery,
              upvoted: null,
              downvoted: "true",
              nominated: "true",
              q: null,
              term_value_id: null,
              order_by: this.state.tabSorts.downvoted[0].order_by,
              order: this.state.tabSorts.downvoted[0].order,
              sortKey: this.state.tabSorts.downvoted[0].key
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          Downvoted (hidden)
        </button>
        <button
          type="button"
          className={`btn btn-default${activeTab === "no-votes" ? " active" : ""}`}
          onClick={( ) => {
            if ( activeTab === "no-votes" ) {
              return;
            }
            setIdentificationsQuery( {
              ...identificationsQuery,
              upvoted: "false",
              downvoted: "false",
              nominated: "true",
              q: null,
              term_value_id: null,
              order_by: this.state.tabSorts["no-votes"][0].order_by,
              order: this.state.tabSorts["no-votes"][0].order,
              sortKey: this.state.tabSorts["no-votes"][0].key
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          No Votes
        </button>
        <button
          type="button"
          className={`btn btn-default${activeTab === "not-nominated" ? " active" : ""}`}
          onClick={( ) => {
            if ( activeTab === "not-nominated" ) {
              return;
            }

            setIdentificationsQuery( {
              ...identificationsQuery,
              upvoted: null,
              downvoted: null,
              nominated: "false",
              q: null,
              term_value_id: null,
              order_by: this.state.tabSorts["not-nominated"][0].order_by,
              order: this.state.tabSorts["not-nominated"][0].order,
              sortKey: this.state.tabSorts["not-nominated"][0].key
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          Not Nominated
        </button>
      </div>
    );
  }

  sortSelect( ) {
    const {
      identificationsQuery,
      setIdentificationsQuery
    } = this.props;
    const activeTab = this.activeTab( );
    const sortOptions = this.state.tabSorts[activeTab];
    return (
      <select
        name="sort"
        className="form-control"
        onChange={e => {
          const selectedSort = this.state.allSorts[e.target.value];
          setIdentificationsQuery( {
            ...identificationsQuery,
            order_by: selectedSort.order_by,
            order: selectedSort.order,
            sortKey: e.target.value
          } );
        }}
        value={identificationsQuery.sortKey}
      >
        { sortOptions.map( sortOption => (
          <option
            value={sortOption.key}
            key={`params-order-by-${sortOption.key}`}
          >
            { I18n.t( sortOption.label, { defaultValue: sortOption.label } ) }
          </option>
        ) ) }
      </select>
    );
  }

  resultAnnotations( ) {
    const {
      response,
      identificationsQuery,
      setIdentificationsQuery
    } = this.props;

    const allAttributeValues = [];
    if ( response?.results?.length > 0 ) {
      _.each( response.category_controlled_terms, annotation => {
        allAttributeValues.push( {
          term: annotation.controlled_attribute,
          value: annotation.controlled_value
        } );
      } );
    }
    const uniqueAttributeValues = _.sortBy(
      allAttributeValues,
      ["term.label", "value.label"]
    );
    if ( _.isEmpty( uniqueAttributeValues ) ) {
      return null;
    }

    return (
      <div className="annotation-search">
        { uniqueAttributeValues.map( termValue => (
          <button
            type="button"
            className={`btn btn-default btn-sm${identificationsQuery.term_value_id === termValue.value.id ? " active" : ""}`}
            key={`term-${termValue.term.id}-value-${termValue.value.id}`}
            onClick={( ) => {
              if ( identificationsQuery.term_value_id === termValue.value.id ) {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: null
                } );
              } else {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: termValue.value.id
                } );
              }
            }}
          >
            {termValue.term.label }
            :&nbsp;
            {termValue.value.label}
          </button>
        ) ) }
      </div>
    );
  }

  render( ) {
    const {
      response,
      identificationsQuery,
      setIdentificationsQuery,
      updateCurrentUser,
      bounds,
      latitude,
      longitude,
      zoomLevel,
      config,
      taxon,
      currentUser
    } = this.props;
    let content;
    const isAdmin = currentUser?.roles.indexOf( "admin" ) >= 0;
    if ( !isAdmin ) {
      return null;
    }
    if ( response?.results?.length === 0 ) {
      content = (
        <div className="no-identifications">
          No results
        </div>
      );
    } else if ( response?.results?.length > 0 ) {
      content = _.map( response.results, result => this.identificationPanel( result ) );
    }
    return (
      <Grid className="IdentificationsTab">
        <Row>
          <Col xs={8}>
            <h2>
              {I18n.t( "identifications" )}
            </h2>
            <div className={`search-container${response?.loading ? " disabled" : ""}`}>
              {this.identificationCategories( )}
              <form
                className="search"
                onSubmit={e => {
                  setIdentificationsQuery( {
                    ...identificationsQuery,
                    q: $( e.target ).find( "[name='q']" ).val( )
                  } );
                  e.preventDefault( );
                }}
              >
                <div className="input-group">
                  <div className="search-input">
                    <input
                      className="form-control"
                      name="q"
                      id="identifications_search_query"
                      type="text"
                      placeholder="Search Identifications"
                      autoComplete="off"
                      onChange={e => {
                        this.setSearchSearchTermPresent( !_.isEmpty( e.target.value ) );
                      }}
                    />
                    { this.state.searchSearchTermPresent && (
                      <span
                        type="button"
                        aria-hidden="true"
                        className="glyphicon glyphicon-remove-circle searchclear"
                        onClick={( ) => {
                          $( "#identifications_search_query" ).val( "" );
                          this.setSearchSearchTermPresent( false );
                          setIdentificationsQuery( {
                            ...identificationsQuery,
                            q: null
                          } );
                        }}
                      />
                    ) }
                  </div>
                  <span className="input-group-btn">
                    <input
                      type="submit"
                      className="btn btn-primary"
                      value="Search"
                    />
                  </span>
                  { this.sortSelect( ) }
                </div>
                { this.resultAnnotations( ) }
              </form>
            </div>
            { response?.loading ? (
              <div className="loading">
                <div className="loading_spinner" />
              </div>
            ) : content }
          </Col>
          <Col xs={4}>
            <Row>
              <div className="taxon-map-container">
                <TaxonMap
                  placement="taxa-show-identifications"
                  showAllLayer={false}
                  minZoom={1}
                  gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
                  taxonLayers={[
                    taxonLayerForTaxon( taxon, {
                      currentUser: config.currentUser,
                      updateCurrentUser
                    } )
                  ]}
                  minX={bounds ? bounds.swlng : null}
                  minY={bounds ? bounds.swlat : null}
                  maxX={bounds ? bounds.nelng : null}
                  maxY={bounds ? bounds.nelat : null}
                  latitude={latitude}
                  longitude={longitude}
                  zoomLevel={zoomLevel}
                  gestureHandling="auto"
                  currentUser={config.currentUser}
                  updateCurrentUser={updateCurrentUser}
                  reloadKey={`taxa-show-identifications-map-${taxon.id}${bounds ? "-bounds" : ""}`}
                  showLegend
                />
              </div>
            </Row>
          </Col>
        </Row>
      </Grid>
    );
  }
}

IdentificationsTab.propTypes = {
  response: PropTypes.object,
  identificationsQuery: PropTypes.object,
  setIdentificationsQuery: PropTypes.func,
  updateCurrentUser: PropTypes.func,
  config: PropTypes.object,
  currentUser: PropTypes.object,
  bounds: PropTypes.object,
  latitude: PropTypes.number,
  longitude: PropTypes.number,
  zoomLevel: PropTypes.number,
  taxon: PropTypes.object,
  nominateIdentification: PropTypes.func,
  unnominateIdentification: PropTypes.func,
  voteIdentification: PropTypes.func,
  unvoteIdentification: PropTypes.func
};

export default IdentificationsTab;
