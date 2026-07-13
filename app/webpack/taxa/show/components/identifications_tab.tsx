import _ from "lodash";
import React, { Component } from "react";
import ReactDOMServer from "react-dom/server";
import {
  Panel,
  Dropdown,
  MenuItem
} from "react-bootstrap";
import moment from "moment-timezone";
// @ts-ignore
import Pagination from "rc-pagination"; // eslint-disable-line
import TaxonMap from "../../../observations/identify/components/taxon_map";
import { taxonLayerForTaxon } from "../../shared/util";
import UserText from "../../../shared/components/user_text";
import UsersPopover from "../../../observations/show/components/users_popover";
import UserLink from "../../../shared/components/user_link";
import type {
  Taxon, CurrentUser, Config, User
} from "../../../shared/types";

// Use custom relative times for moment
/* eslint-disable @typescript-eslint/no-explicit-any */
const i18nMomentjs = I18n.t( "momentjs" ) as any;
const shortRelativeTime = i18nMomentjs ? i18nMomentjs.shortRelativeTime : null;
const relativeTime = {
  ...( I18n.t( "momentjs", { locale: "en" } ) as any ).shortRelativeTime,
  ...shortRelativeTime
};
moment.locale( ( I18n as any ).locale );
moment.updateLocale( moment.locale( ), { relativeTime } );
/* eslint-enable @typescript-eslint/no-explicit-any */

interface SortOption {
  key: string;
  label: string;
  order_by: string;
  order: string;
}

interface IdentificationsQuery {
  downvoted?: string | null;
  upvoted?: string | null;
  nominated?: string | null;
  q?: string | null;
  term_value_id?: number | null;
  order_by?: string;
  order?: string;
  sortKey?: string;
  page?: number | null;
}

interface IdentificationVote {
  vote_flag: boolean;
  user?: { id: number };
}

interface AnnotationValue {
  id: number;
  label: string;
}

interface IdentificationObservation {
  id: number;
  photos: { photoUrl: ( size?: string ) => string }[];
  annotations: {
    uuid: string;
    controlled_attribute: AnnotationValue;
    controlled_value: AnnotationValue;
  }[];
  discussion_count: number;
}

interface Identification {
  uuid: string;
  id: number;
  user: User;
  observation: IdentificationObservation;
  body: string;
  created_at: string;
}

interface IdentificationResult {
  id: number;
  identification: Identification;
  votes: IdentificationVote[];
  nominated_by_user?: User;
  nominated_at?: string;
}

interface IdentificationsResponse {
  results?: IdentificationResult[];
  total_results?: number;
  page?: number;
  per_page?: number;
  loading?: boolean;
  category_counts?: Record<string, number>;
  category_controlled_terms?: {
    controlled_attribute: AnnotationValue;
    controlled_value: AnnotationValue;
  }[];
}

interface Bounds {
  swlng?: number;
  swlat?: number;
  nelng?: number;
  nelat?: number;
}

interface Props {
  response?: IdentificationsResponse;
  identificationsQuery: IdentificationsQuery;
  identificationsAvailable?: boolean;
  setIdentificationsQuery: ( query: IdentificationsQuery ) => void;
  updateCurrentUser?: ( user: Partial<CurrentUser> ) => void;
  config: Config;
  currentUser?: CurrentUser;
  bounds?: Bounds;
  latitude?: number;
  longitude?: number;
  zoomLevel?: number;
  taxon: Taxon;
  nominateIdentification?: ( uuid: string, id: number ) => void;
  unnominateIdentification?: ( uuid: string, id: number ) => void;
  voteIdentification?: ( id: number, type?: string ) => void;
  unvoteIdentification?: ( id: number ) => void;
}

interface State {
  searchSearchTermPresent: boolean | null;
  allSorts: Record<string, SortOption>;
  tabSorts: Record<string, SortOption[]>;
}

class IdentificationsTab extends Component<Props, State> {
  constructor( props: Props, context: unknown ) {
    super( props, context );
    const allSorts: Record<string, SortOption> = {
      votesDesc: {
        key: "votesDesc",
        label: I18n.t( "views.taxa.show.identifications.sort.highest_to_lowest_votes" ),
        order_by: "votes",
        order: "desc"
      },
      votesAsc: {
        key: "votesAsc",
        label: I18n.t( "views.taxa.show.identifications.sort.lowest_to_highest_votes" ),
        order_by: "votes",
        order: "asc"
      },
      newest: {
        key: "newest",
        label: I18n.t( "views.taxa.show.identifications.sort.newest_to_oldest" ),
        order_by: "created_at",
        order: "desc"
      },
      oldest: {
        key: "oldest",
        label: I18n.t( "views.taxa.show.identifications.sort.oldest_to_newest" ),
        order_by: "created_at",
        order: "asc"
      },
      lengthDesc: {
        key: "lengthDesc",
        label: I18n.t( "views.taxa.show.identifications.sort.longest_to_shortest" ),
        order_by: "word_count",
        order: "desc"
      }
    };
    const tabSorts: Record<string, SortOption[]> = {
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

  setSearchSearchTermPresent( present: boolean ) {
    if ( this.state.searchSearchTermPresent === present ) {
      return;
    }

    this.setState( {
      searchSearchTermPresent: present
    } );
  }

  panelMenu( result: IdentificationResult ) {
    const {
      config,
      nominateIdentification,
      unnominateIdentification
    } = this.props;
    const loggedInUser = ( config && config.currentUser ) ? config.currentUser : null;
    const nominationMenuItems = [];
    if ( loggedInUser ) {
      nominationMenuItems.push( (
        <MenuItem
          key={`id-flag-${result.id}`}
          eventKey="flag"
        >
          { I18n.t( "flag" ) }
        </MenuItem>
      ) );
      if ( loggedInUser.isCurator ) {
        nominationMenuItems.push( (
          <MenuItem
            key={`id-hide-${result.identification.uuid}`}
            eventKey="hide"
          >
            { I18n.t( "hide_content" ) }
          </MenuItem>
        ) );
      }
    }
    if ( result.nominated_by_user
      && config?.currentUser?.canUnnominateIdentification( result.identification )
    ) {
      nominationMenuItems.push( (
        <MenuItem
          key="id-unnominate"
          eventKey="unnominate"
        >
          { I18n.t( "identification_tips.remove_nomination" ) }
        </MenuItem>
      ) );
    }
    if ( !result.nominated_by_user
      && config?.currentUser?.canNominateIdentification( result.identification )
    ) {
      nominationMenuItems.push( (
        <MenuItem
          key="id-nominate"
          eventKey="nominate"
        >
          { I18n.t( "identification_tips.nominate" ) }
        </MenuItem>
      ) );
    }
    if ( _.isEmpty( nominationMenuItems ) ) {
      return null;
    }

    return (
      <div className="menu">
        <span className="control-group">
          <Dropdown
            id="grouping-control"
            onSelect={( key: string ) => {
              if ( key === "flag" ) {
                const url = `/identifications/${result.identification.uuid}?_action=flag`;
                window.open( url, "_blank", "noopener,noreferrer" );
              } else if ( key === "hide" ) {
                const url = `/identifications/${result.identification.uuid}?_action=hide`;
                window.open( url, "_blank", "noopener,noreferrer" );
              } else if ( key === "nominate" ) {
                nominateIdentification?.( result.identification.uuid, result.id );
              } else if ( key === "unnominate" ) {
                unnominateIdentification?.( result.identification.uuid, result.id );
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
    );
  }

  identificationPanel( result: IdentificationResult ) {
    const {
      config,
      identificationsQuery,
      setIdentificationsQuery,
      voteIdentification,
      unvoteIdentification
    } = this.props;
    const userCanVote = config?.currentUser?.canUnnominateIdentification( result.identification );
    const annotations = (
      <div className="annotations">
        {_.map( result.identification.observation.annotations, annotation => (
          <button
            type="button"
            className={`btn btn-default btn-sm${identificationsQuery.term_value_id === annotation.controlled_value.id ? " active" : ""}`}
            key={annotation.uuid}
            onClick={( ) => {
              if ( identificationsQuery.term_value_id === annotation.controlled_value.id ) {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: null,
                  page: null
                } );
              } else {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: annotation.controlled_value.id,
                  page: null
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
    } else {
      img = (
        <i className="icon icon-iconic-aves" />
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
    const votesFor: IdentificationVote[] = [];
    const votesAgainst: IdentificationVote[] = [];
    let userVotedFor = false;
    let userVotedAgainst = false;
    _.each( result.votes, v => {
      if ( v.vote_flag === true ) {
        votesFor.push( v );
      } else if ( v.vote_flag === false ) {
        votesAgainst.push( v );
      }
      if ( v.user?.id === config.currentUser?.id ) {
        userVotedFor = ( v.vote_flag === true );
        userVotedAgainst = ( v.vote_flag === false );
      }
    } );
    const voteAction = () => (
      userVotedFor ? unvoteIdentification?.( result.id ) : voteIdentification?.( result.id )
    );
    const unvoteAction = () => (
      userVotedAgainst ? unvoteIdentification?.( result.id ) : voteIdentification?.( result.id, "bad" )
    );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";

    const userLink = (
      <UserLink
        className="user"
        config={config}
        noInativersary
        href={`/identifications/${result.identification.uuid}`}
        user={result.identification.user}
      />
    );

    const nominatedByUserLink = result.nominated_by_user && (
      <UserLink
        className="user"
        config={config}
        noInativersary
        href={`/identifications/${result.identification.uuid}`}
        user={result.nominated_by_user}
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
                  {this.panelMenu( result )}
                </Panel.Title>
              </Panel.Heading>
              <Panel.Body>
                <div className="body">
                  <UserText text={result.identification.body} className="id_body" />
                </div>
              </Panel.Body>
              { nominatedByUserLink && (
                <Panel.Footer>
                  <span
                    className="footer-text"
                    // eslint-disable-next-line react/no-danger
                    dangerouslySetInnerHTML={{
                      __html: I18n.t( "identification_tips.user_nominated_this_as_an_id_tip_html", {
                        user: ReactDOMServer.renderToString( nominatedByUserLink )
                      } )
                    }}
                  />
                  <time
                    className="time"
                    dateTime={result.nominated_at}
                    title={moment( result.nominated_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
                  >
                    {moment.parseZone( result.nominated_at ).fromNow( )}
                  </time>
                  { result.nominated_by_user && (
                    <div className="votes">
                      { userCanVote && (
                        <button
                          type="button"
                          className="btn btn-nostyle"
                          onClick={voteAction}
                          aria-label={I18n.t( "agree_" )}
                          title={I18n.t( "agree_" )}
                        >
                          <i className={`fa ${agreeClass}`} />
                        </button>
                      ) }
                      { !userCanVote && (
                        <i className={`fa ${agreeClass}`} />
                      )}
                      { !_.isEmpty( votesFor ) && (
                        <UsersPopover
                          users={_.map( votesFor, "user" )}
                          keyPrefix={`votes-against-${result.identification.uuid}`}
                          contents={(
                            <span>{votesFor.length === 0 ? null : votesFor.length}</span>
                          )}
                        />
                      ) }
                      { userCanVote && (
                        <button
                          type="button"
                          onClick={unvoteAction}
                          className="btn btn-nostyle"
                          aria-label={I18n.t( "disagree_" )}
                          title={I18n.t( "disagree_" )}
                        >
                          <i className={`fa ${disagreeClass}`} />
                        </button>
                      ) }
                      { !userCanVote && (
                        <i className={`fa ${disagreeClass}`} />
                      )}
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
                </Panel.Footer>
              ) }
            </Panel>
            <div className="annotations-conversation">
              {annotations}
              {result.identification.observation.discussion_count > 1 && (
                <div className="conversation">
                  <a href={`/observations/${result.identification.observation.id}`}>
                    { I18n.t( "views.taxa.show.identifications.view_full_conversation" ) }
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

  categoryTabDisabled( category: string ) {
    const { response } = this.props;
    if ( !response?.category_counts ) {
      return true;
    }
    return response.category_counts[category] === 0;
  }

  identificationCategories( ) {
    const {
      identificationsQuery,
      setIdentificationsQuery,
      config
    } = this.props;
    if ( !config?.currentUser?.canNominateHelpfulIDTips( ) ) {
      return null;
    }

    const activeTab = this.activeTab( );
    const upvotedDisabled = this.categoryTabDisabled( "upvoted" );
    const downvotedDisabled = this.categoryTabDisabled( "downvoted" );
    const noVotesDisabled = this.categoryTabDisabled( "no_votes" );
    const notNominatedDisabled = this.categoryTabDisabled( "not_nominated" );
    return (
      <div className="btn-group identification-categories">
        <button
          type="button"
          className={
            `btn btn-default${activeTab === "upvoted" ? " active" : ""}`
            + `${upvotedDisabled ? " disabled " : ""}`
          }
          disabled={upvotedDisabled}
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
              sortKey: this.state.tabSorts.upvoted[0].key,
              page: null
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          { I18n.t( "views.taxa.show.identifications.upvoted" ) }
        </button>
        <button
          type="button"
          className={
            `btn btn-default${activeTab === "downvoted" ? " active" : ""}`
            + `${downvotedDisabled ? " disabled " : ""}`
          }
          disabled={downvotedDisabled}
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
              sortKey: this.state.tabSorts.downvoted[0].key,
              page: null
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          { I18n.t( "views.taxa.show.identifications.downvoted_and_hidden" ) }
        </button>
        <button
          type="button"
          className={
            `btn btn-default${activeTab === "no-votes" ? " active" : ""}`
            + `${noVotesDisabled ? " disabled " : ""}`
          }
          disabled={noVotesDisabled}
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
              sortKey: this.state.tabSorts["no-votes"][0].key,
              page: null
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          { I18n.t( "views.taxa.show.identifications.no_votes" ) }
        </button>
        <button
          type="button"
          className={
            `btn btn-default${activeTab === "not-nominated" ? " active" : ""}`
            + `${notNominatedDisabled ? " disabled " : ""}`
          }
          disabled={notNominatedDisabled}
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
              sortKey: this.state.tabSorts["not-nominated"][0].key,
              page: null
            } );
            $( "#identifications_search_query" ).val( "" );
          }}
        >
          { I18n.t( "views.taxa.show.identifications.not_nominated" ) }
        </button>
      </div>
    );
  }

  searchForm( ) {
    const {
      identificationsQuery,
      setIdentificationsQuery,
      identificationsAvailable,
      config
    } = this.props;
    if ( identificationsAvailable === false && !config?.currentUser?.canNominateHelpfulIDTips( ) ) {
      return null;
    }
    return (
      <form
        className="search"
        onSubmit={e => {
          setIdentificationsQuery( {
            ...identificationsQuery,
            q: $( e.target as Element ).find( "[name='q']" ).val( ),
            page: null
          } );
          e.preventDefault( );
        }}
      >
        <div className="search-bar-row">
          <div className="input-group">
            <div className="search-input">
              <input
                className="form-control"
                name="q"
                id="identifications_search_query"
                type="text"
                placeholder={I18n.t( "views.taxa.show.identifications.search_identifications" )}
                autoComplete="off"
                onChange={e => {
                  this.setSearchSearchTermPresent( !_.isEmpty( e.target.value ) );
                }}
              />
              { this.state.searchSearchTermPresent && (
                <span
                  role="button"
                  aria-hidden="true"
                  className="glyphicon glyphicon-remove-circle searchclear"
                  onClick={( ) => {
                    $( "#identifications_search_query" ).val( "" );
                    this.setSearchSearchTermPresent( false );
                    setIdentificationsQuery( {
                      ...identificationsQuery,
                      q: null,
                      page: null
                    } );
                  }}
                />
              ) }
            </div>
            <span className="input-group-btn">
              <input
                type="submit"
                className="btn btn-primary"
                value={I18n.t( "search" )}
              />
            </span>
          </div>
          <div className="sort-row">
            { this.sortSelect( ) }
          </div>
        </div>
        { this.resultAnnotations( ) }
      </form>
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
            sortKey: e.target.value,
            page: null
          } );
        }}
        value={identificationsQuery.sortKey}
      >
        { sortOptions.map( sortOption => (
          <option
            value={sortOption.key}
            key={`params-order-by-${sortOption.key}`}
          >
            { sortOption.label }
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

    const allAttributeValues: { term: AnnotationValue; value: AnnotationValue }[] = [];
    if ( ( response?.results?.length ?? 0 ) > 0 ) {
      _.each( response?.category_controlled_terms, annotation => {
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
                  term_value_id: null,
                  page: null
                } );
              } else {
                setIdentificationsQuery( {
                  ...identificationsQuery,
                  term_value_id: termValue.value.id,
                  page: null
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
      identificationsAvailable,
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
    let pagination;
    const responsive = currentUser?.isAdmin
      && currentUser?.isInTestGroup( "responsive-taxon-detail" );
    const activeTab = this.activeTab( );
    if ( response?.results?.length === 0 ) {
      content = (
        <div className="no-identifications">
          {
            activeTab === "upvoted" && identificationsAvailable === false
              ? I18n.t( "views.taxa.show.identifications.no_nominated_and_upvoted_identifications" )
              : I18n.t( "no_results_found" )
          }
        </div>
      );
    } else if ( ( response?.results?.length ?? 0 ) > 0 ) {
      content = _.map( response?.results, result => this.identificationPanel( result ) );
      pagination = (
        <Pagination
          total={response?.total_results}
          current={response?.page}
          pageSize={response?.per_page}
          locale={{
            prev_page: I18n.t( "previous_page_short" ),
            next_page: I18n.t( "next_page_short" )
          }}
          onChange={( page: number ) => setIdentificationsQuery( {
            ...identificationsQuery,
            page
          } )}
        />
      );
    }
    return (
      <div className="IdentificationsTab">
        <div className={`ident-layout${responsive ? " responsive" : ""}`}>
          <div className="ident-main">
            <h2>
              {I18n.t( "views.taxa.show.identifications.identification_tips" )}
            </h2>
            <div className={`search-container${response?.loading ? " disabled" : ""}`}>
              {this.identificationCategories( )}
              {this.searchForm( )}
            </div>
            { response?.loading ? (
              <div className="loading">
                <div className="loading_spinner" />
              </div>
            ) : (
              <>
                {content}
                {pagination}
              </>
            ) }
          </div>
          <div className={`ident-side${responsive ? " hidden-xs" : ""}`}>
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
          </div>
        </div>
      </div>
    );
  }
}

export default IdentificationsTab;
