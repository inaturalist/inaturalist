import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
import _ from "lodash";
import {
  OverlayTrigger,
  Panel,
  Tooltip,
  Popover
} from "react-bootstrap";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";
import UserImage from "../../../shared/components/user_image";
import ActivityItemMenu from "./activity_item_menu";
import util from "../util";
import { urlForTaxon } from "../../../taxa/shared/util";
import TextEditor from "../../../shared/components/text_editor";

class ActivityItem extends React.Component {
  constructor( props ) {
    super( props );
    const { item } = this.props;
    this.isID = !!item.taxon;
    this.changeHandler = this.changeHandler.bind( this );

    this.state = {
      editing: false,
      textareaContent: item.body
    };
  }

  componentDidUpdate( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "textarea", domNode ).textcompleteUsers();
  }

  onEdit( e ) {
    const { inlineEditing } = this.props;
    if ( inlineEditing ) {
      const { editing } = this.state;
      e.preventDefault( );
      this.setState( { editing: !editing } );
    }
  }

  /*
    Optional prop passed to child TextEditor, called on textarea change.
    Used here to keep ActivityItem state of content in sync with child TextEditors
    and parent Activity.
   */
  changeHandler( textareaContent ) {
    this.setState( { textareaContent } );
  }

  editItemForm( ) {
    const { item } = this.props;
    const { textareaContent, editing } = this.state;
    return (
      <div className="form-group edit-comment-id">
        <TextEditor
          content={textareaContent}
          changeHandler={this.changeHandler}
          key={`comment-editor-${item.uuid}`}
          placeholder={this.isID ? I18n.t( "tell_us_why" ) : I18n.t( "leave_a_comment" )}
          textareaClassName="form-control"
          maxLength={5000}
          showCharsRemainingAt={4000}
        />
        <div className="btn-group edit-form-btns">
          <button
            type="button"
            className="btn btn-primary btn-sm"
            onClick={( ) => this.updateItem( )}
          >
            { this.isID ? I18n.t( "save_identification" ) : I18n.t( "save_comment" ) }
          </button>
          <button
            type="button"
            className="btn btn-default btn-sm"
            onClick={( ) => this.setState( { editing: !editing } )}
          >
            { I18n.t( "cancel" ) }
          </button>
          { this.isID && (
            <button
              type="button"
              className="btn btn-link btn-sm pull-right"
              onClick={( ) => this.deleteIdentification( )}
            >
              { I18n.t( "delete" ) }
            </button>
          ) }
        </div>
      </div>
    );
  }

  updateItem( ) {
    const { item, editComment, editID } = this.props;
    const { textareaContent, editing } = this.state;
    if ( this.isID ) {
      editID( item.uuid, textareaContent );
    } else {
      editComment( item.uuid, textareaContent );
    }
    this.setState( { editing: !editing } );
  }

  deleteIdentification( ) {
    const { item, confirmDeleteID } = this.props;
    const { editing } = this.state;
    confirmDeleteID( item.uuid );
    this.setState( { editing: !editing } );
  }

  render( ) {
    const {
      observation,
      item,
      config,
      deleteComment,
      restoreID,
      setFlaggingModalState,
      currentUserID,
      addID,
      linkTarget,
      hideCompare,
      hideDisagreement,
      hideCategory,
      noTaxonLink,
      onClickCompare,
      trustUser,
      untrustUser,
      showHidden,
      hideContent,
      unhideContent,
      withdrawID
    } = this.props;
    const { editing } = this.state;

    if ( !item ) {
      return ( <div /> );
    }
    const { taxon } = item;
    const loggedIn = config && config.currentUser;
    const canSeeHidden = config && config.currentUser && (
      config.currentUser.roles.indexOf( "admin" ) >= 0
      || config.currentUser.roles.indexOf( "curator" ) >= 0
      || config.currentUser.id === item.user.id
    );
    const viewerIsActor = config.currentUser && item.user.id === config.currentUser.id;
    let contents;
    let header;
    let className = "comment";
    if ( item.hidden && this.isID && ( !canSeeHidden || !config.showHidden ) ) {
      return (
        <div className="ActivityItem">
          <div className="icon">
            <UserImage user={viewerIsActor ? item.user : null} />
          </div>
          <Panel className="moderator-hidden">
            <Panel.Heading>
              <Panel.Title>
                <span className="title_text text-muted"><i>{I18n.t( "content_hidden" )}</i></span>
                {canSeeHidden && (
                  <button
                    href="#"
                    type="button"
                    className="btn btn-default btn-xs"
                    onClick={() => showHidden()}
                  >
                    {I18n.t( "show_hidden_content" )}
                  </button>
                )}
              </Panel.Title>
            </Panel.Heading>
          </Panel>
        </div>
      );
    }
    const userLink = (
      <a
        className="user"
        href={`/people/${item.user.login}`}
        target={linkTarget}
      >
        {item.user.login}
      </a>
    );
    if ( this.isID ) {
      className = "identification";
      const buttons = [];
      let canAgree = false;
      let userAgreedToThis;
      if (
        loggedIn
        && item.current
        && item.firstDisplay
        && item.user.id !== config.currentUser.id
        && ( item.taxon && item.taxon.is_active )
      ) {
        if ( currentUserID ) {
          canAgree = currentUserID.taxon.id !== taxon.id;
          userAgreedToThis = currentUserID.agreedTo && currentUserID.agreedTo.uuid === item.uuid;
        } else {
          canAgree = true;
        }
      }
      if ( loggedIn && item.firstDisplay && !hideCompare ) {
        let compareTaxonID = taxon.id;
        if ( taxon.rank_level <= 10 ) {
          compareTaxonID = taxon.ancestor_ids[taxon.ancestor_ids.length - 1];
        }
        buttons.push( (
          <a
            key={`id-compare-${item.uuid}`}
            href={`/observations/identotron?observation_id=${observation.id}&taxon=${compareTaxonID}`}
          >
            <button
              type="button"
              className="btn btn-default btn-sm"
              onClick={e => {
                if ( onClickCompare ) {
                  return onClickCompare( e, taxon, observation,
                    { currentUser: config.currentUser } );
                }
                return true;
              }}
            >
              <i className="fa fa-exchange" />
              {" "}
              {I18n.t( "compare" )}
            </button>
          </a>
        ) );
      }
      if ( loggedIn && ( canAgree || userAgreedToThis ) ) {
        buttons.push( (
          <button
            type="button"
            key={`id-agree-${item.uuid}`}
            className="btn btn-default btn-sm"
            onClick={() => {
              addID( taxon, { agreedTo: item } );
            }}
            disabled={userAgreedToThis}
          >
            {userAgreedToThis ? ( <div className="loading_spinner" /> )
              : ( <i className="fa fa-check" /> )}
            {" "}
            {I18n.t( "agree_" )}
          </button>
        ) );
      }
      const buttonDiv = (
        <div className="buttons">
          <div className="btn-space">
            {buttons}
          </div>
        </div>
      );
      const taxonImageTag = util.taxonImage( taxon );
      header = I18n.t( "user_suggested_an_id", { user: ReactDOMServer.renderToString( userLink ) } );
      if ( item.disagreement ) {
        header += "*";
      }
      if ( !item.current ) {
        className = "withdrawn";
      }
      let idBody;
      if ( item.hidden && !config.showHidden ) {
        idBody = (
          <div className="hidden-content upstacked text-muted well well-sm">
            <i>{I18n.t( "content_hidden" )}</i>
            {canSeeHidden && (
              <button
                href="#"
                type="button"
                className="btn btn-default btn-xs"
                onClick={() => showHidden()}
              >
                {I18n.t( "show_hidden_content" )}
              </button>
            )}
          </div>
        );
      } else if ( !item.hidden || canSeeHidden ) {
        if ( editing ) {
          idBody = this.editItemForm( );
        } else if ( item.body && item.body.length > 0 ) {
          idBody = <UserText text={item.body} className="id_body" />;
        }
      }
      contents = (
        <div className="identification">
          {buttonDiv}
          <div className="taxon">
            {noTaxonLink ? taxonImageTag : (
              <a href={`/taxa/${taxon.id}`} target={linkTarget}>
                {taxonImageTag}
              </a>
            )}
            <SplitTaxon
              taxon={taxon}
              url={noTaxonLink ? null : `/taxa/${taxon.id}`}
              noParens
              target={linkTarget}
              user={config.currentUser}
              showMemberGroup
            />
          </div>
          { idBody }
        </div>
      );
    } else if ( !item.hidden || canSeeHidden ) {
      header = I18n.t( "user_commented", { user: ReactDOMServer.renderToString( userLink ) } );
      contents = editing ? this.editItemForm( ) : ( <UserText text={item.body} /> );
    }
    const relativeTime = moment.parseZone( item.created_at ).fromNow();
    let panelClass;
    const headerItems = [];
    const unresolvedFlags = _.filter( item.flags || [], f => !f.resolved );
    if ( item.hidden ) {
      const moderatorAction = _.sortBy(
        _.filter( item.moderator_actions, ma => ma.action === "hide" ),
        ma => ma.id * -1
      )[0];
      const maUserLink = (
        <a
          href={`/people/${moderatorAction.user.login}`}
          target="_blank"
          rel="noopener noreferrer"
        >
          {`@${moderatorAction.user.login}`}
        </a>
      );
      headerItems.push(
        <OverlayTrigger
          key={`hidden-tooltip-${item.uuid}`}
          container={$( "#wrapper.bootstrap" ).get( 0 )}
          placement="top"
          trigger="click"
          rootClose
          delayShow={200}
          overlay={(
            <Popover
              id={`hidden-${item.uuid}`}
              className="unhide-popover"
            >
              <span
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "content_hidden_by_user_on_date_because_reason_html", {
                    user: ReactDOMServer.renderToString( maUserLink ),
                    date: I18n.localize( "date.formats.month_day_year", moderatorAction.created_at ),
                    reason: ReactDOMServer.renderToString( <UserText text={moderatorAction.reason} className="inline" /> )
                  } )
                }}
              />
              <div className="upstacked text-muted">
                <a
                  href={`/${this.isID ? "identifications" : "comments"}/${item.uuid}/flags`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="linky"
                >
                  {I18n.t( "view_moderation_history" )}
                </a>
                {viewerIsActor && (
                  <span>
                    <br />
                    <a
                      href="/help"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="linky"
                    >
                      {I18n.t( "contact_support" )}
                    </a>
                  </span>
                )}
              </div>
            </Popover>
          )}
        >
          <span className="item-status hidden-status">
            <i className="fa fa-eye-slash" title={I18n.t( "content_hidden" )} />
            <span className="hidden-xs hidden-sm">
              {" "}
              {I18n.t( "content_hidden" )}
            </span>
          </span>
        </OverlayTrigger>
      );
    }
    if ( unresolvedFlags.length > 0 ) {
      panelClass = "flagged";
      headerItems.push(
        <span key={`flagged-${item.uuid}`} className="item-status">
          <a
            href={`/${this.isID ? "identifications" : "comments"}/${item.uuid}/flags`}
            rel="nofollow noopener noreferrer"
            target="_blank"
          >
            <i className="fa fa-flag" />
            {" "}
            {I18n.t( "flagged_" )}
          </a>
        </span>
      );
    } else if ( item.category && item.current && !hideCategory ) {
      let idCategory;
      let idCategoryTooltipText;
      if ( item.category === "maverick" ) {
        panelClass = "maverick";
        idCategory = (
          <span key={`maverick-${item.uuid}`} className="item-status ident-category">
            <i className="fa fa-bolt" />
            {" "}
            {I18n.t( "maverick" )}
          </span>
        );
        idCategoryTooltipText = I18n.t( "id_categories.tooltips.maverick" );
      } else if ( item.category === "improving" ) {
        panelClass = "improving";
        idCategory = (
          <span key={`improving-${item.uuid}`} className="item-status ident-category">
            <i className="fa fa-trophy" />
            {" "}
            {I18n.t( "improving" )}
          </span>
        );
        idCategoryTooltipText = I18n.t( "id_categories.tooltips.improving" );
      } else if ( item.category === "leading" ) {
        panelClass = "leading";
        idCategory = (
          <span key={`leading-${item.uuid}`} className="item-status ident-category">
            <i className="icon-icn-leading-id" />
            {" "}
            {I18n.t( "leading" )}
          </span>
        );
        idCategoryTooltipText = I18n.t( "id_categories.tooltips.leading" );
      }
      if ( idCategory ) {
        headerItems.push(
          <OverlayTrigger
            key={`ident-category-tooltip-${item.uuid}`}
            container={$( "#wrapper.bootstrap" ).get( 0 )}
            placement="top"
            delayShow={200}
            overlay={(
              <Tooltip id={`tooltip-${item.uuid}`}>
                {idCategoryTooltipText}
              </Tooltip>
            )}
          >
            {idCategory}
          </OverlayTrigger>
        );
      }
    }
    if ( item.vision ) {
      headerItems.push(
        <OverlayTrigger
          key={`itent-vision-${item.uuid}`}
          container={$( "#wrapper.bootstrap" ).get( 0 )}
          trigger="click"
          rootClose
          placement="top"
          delayShow={200}
          overlay={(
            <Popover
              id={`vision-popover-${item.uuid}`}
              title={I18n.t( "computer_vision_suggestion" )}
            >
              {I18n.t( "computer_vision_suggestion_desc" )}
            </Popover>
          )}
        >
          <span className="vision-status">
            <i className="icon-sparkly-label" />
          </span>
        </OverlayTrigger>
      );
    }
    if ( item.taxon && !item.current ) {
      headerItems.push(
        <span key={`ident-withdrawn-${item.uuid}`} className="item-status">
          <i className="fa fa-ban" />
          {" "}
          {I18n.t( "id_withdrawn" )}
        </span>
      );
    }
    let taxonChange;
    if ( item.taxon_change ) {
      const taxonChangeLinkAttrs = {
        url: `/taxon_changes/${item.taxon_change.id}`,
        target: linkTarget,
        class: "linky"
      };
      let taxonChangeLink;
      switch ( item.taxon_change.type ) {
        case "TaxonSwap":
          taxonChangeLink = I18n.t( "added_as_a_part_of_a_taxon_swap_html", taxonChangeLinkAttrs );
          break;
        case "TaxonSplit":
          taxonChangeLink = I18n.t( "added_as_a_part_of_a_taxon_split_html", taxonChangeLinkAttrs );
          break;
        case "TaxonMerge":
          taxonChangeLink = I18n.t( "added_as_a_part_of_a_taxon_merge_html", taxonChangeLinkAttrs );
          break;
        default:
          taxonChangeLink = I18n.t( "added_as_a_part_of_a_taxon_change_html", taxonChangeLinkAttrs );
      }
      taxonChange = (
        <div className="taxon-change">
          <i className="fa fa-refresh" />
          {" "}
          <span
            dangerouslySetInnerHTML={{
              __html: taxonChangeLink
            }}
          />
        </div>
      );
    }
    const byClass = viewerIsActor ? "by-current-user" : "by-someone-else";
    let footer;
    if ( item.disagreement && !hideDisagreement ) {
      const previousTaxonLink = (
        <SplitTaxon
          taxon={item.previous_observation_taxon}
          url={urlForTaxon( item.previous_observation_taxon )}
          target={linkTarget}
          user={config.currentUser}
        />
      );
      const footerText = I18n.t( "user_disagrees_this_is_taxon", {
        user: ReactDOMServer.renderToString( userLink ),
        taxon: ReactDOMServer.renderToString( previousTaxonLink )
      } );
      footer = (
        <span
          className="title_text"
          dangerouslySetInnerHTML={{
            __html: `* ${footerText}`
          }}
        />
      );
    }
    if ( item.implicitDisagreement ) {
      const footerText = I18n.t( "user_disagrees_with_previous_finer_identifications", {
        user: ReactDOMServer.renderToString( userLink )
      } );
      footer = (
        <span
          className="title_text"
          dangerouslySetInnerHTML={{
            __html: `* ${footerText}`
          }}
        />
      );
    }
    const elementID = this.isID ? `activity_identification_${item.uuid}` : `activity_comment_${item.uuid}`;
    const itemURL = this.isID ? `/identifications/${item.uuid}` : `/comments/${item.uuid}`;
    let time = (
      <time
        className="time"
        dateTime={item.created_at}
        title={moment( item.created_at ).format( "LLL" )}
      >
        <a href={itemURL} target={linkTarget}>{relativeTime}</a>
      </time>
    );
    if (
      observation
      && observation.obscured
      && !observation.private_geojson
    ) {
      const coordinatesObscured = observation
        && observation.obscured
        && !observation.private_geojson;
      const viewerCreatedItem = config
        && config.currentUser
        && item.user
        && item.user.id === config.currentUser.id;
      if ( coordinatesObscured && !viewerCreatedItem ) {
        time = (
          <time className="time">
            <i className="icon-icn-location-obscured" title={I18n.t( "date_obscured_notice" )} />
            { moment( item.created_at ).format( I18n.t( "momentjs.month_year_short" ) ) }
          </time>
        );
      }
    }
    return (
      <div id={elementID} className={`ActivityItem ${className} ${byClass}`}>
        <div className="icon">
          {( !item.hidden || canSeeHidden || viewerIsActor ) && (
            <UserImage user={item.user} linkTarget={linkTarget} />
          )}
        </div>
        <Panel className={`${panelClass} ${item.api_status ? "loading" : ""}`}>
          <Panel.Heading>
            <Panel.Title>
              <span className="title_text" dangerouslySetInnerHTML={{ __html: header }} />
              {headerItems}
              { time }
              <ActivityItemMenu
                item={item}
                observation={observation}
                onEdit={e => this.onEdit( e )}
                editing={editing}
                config={config}
                deleteComment={deleteComment}
                withdrawID={withdrawID}
                restoreID={restoreID}
                setFlaggingModalState={setFlaggingModalState}
                linkTarget={linkTarget}
                trustUser={trustUser}
                untrustUser={untrustUser}
                hideContent={hideContent}
                unhideContent={unhideContent}
              />
            </Panel.Title>
          </Panel.Heading>
          <Panel.Body>
            {taxonChange}
            <div className="contents">
              {contents}
            </div>
          </Panel.Body>
          {footer ? <Panel.Footer>{footer}</Panel.Footer> : null}
        </Panel>
      </div>
    );
  }
}

ActivityItem.propTypes = {
  inlineEditing: PropTypes.bool,
  item: PropTypes.object,
  config: PropTypes.object,
  currentUserID: PropTypes.object,
  observation: PropTypes.object,
  addID: PropTypes.func,
  deleteComment: PropTypes.func,
  editComment: PropTypes.func,
  confirmDeleteID: PropTypes.func,
  withdrawID: PropTypes.func,
  editID: PropTypes.func,
  restoreID: PropTypes.func,
  setFlaggingModalState: PropTypes.func,
  linkTarget: PropTypes.string,
  hideCompare: PropTypes.bool,
  hideDisagreement: PropTypes.bool,
  hideCategory: PropTypes.bool,
  noTaxonLink: PropTypes.bool,
  onClickCompare: PropTypes.func,
  trustUser: PropTypes.func,
  untrustUser: PropTypes.func,
  showHidden: PropTypes.func,
  hideContent: PropTypes.func,
  unhideContent: PropTypes.func
};

export default ActivityItem;
