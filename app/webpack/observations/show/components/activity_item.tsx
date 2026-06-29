import React, { useEffect, useRef, useState } from "react";
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
import UserLink from "../../../shared/components/user_link";
import Inativersary from "../../../shared/components/inativersary";
import ActivityItemMenu from "./activity_item_menu";
import util from "../util";
import { urlForTaxon } from "../../../taxa/shared/util";
import TextEditor from "../../../shared/components/text_editor";
import HiddenContentMessageContainer from "../../../shared/containers/hidden_content_message_container";
import HiddenActivityItem from "./hidden_activity_item";
import UsersPopover from "./users_popover";
import type {
  Config, CurrentUser, Observation, Taxon, User
} from "../../../shared/types";

/* eslint-disable react/no-danger */

type ActivityUser = User & { id: number; login: string };

interface Vote {
  vote_flag?: boolean;
  user?: { id?: number };
}

interface ExemplarIdentification {
  id: number;
  nominated_by_user?: { login: string };
  nominated_at?: string;
  votes?: Vote[];
}

interface TaxonChange {
  id: number;
  type?: string;
}

// Comment or Identification model rendered by ActivityItem; carries many fields
// beyond the shared types depending on whether it's an ID or a comment.
export interface ActivityItemModel {
  id: number;
  uuid: string;
  user: ActivityUser;
  body?: string | null;
  created_at: string;
  hidden?: boolean;
  current?: boolean;
  firstDisplay?: boolean;
  category?: string | null;
  vision?: boolean;
  api_status?: string;
  flags?: { resolved?: boolean }[];
  taxon?: Taxon;
  taxon_change?: TaxonChange;
  disagreement?: boolean;
  implicitDisagreement?: boolean;
  previous_observation_taxon_id?: number;
  previous_observation_taxon?: Taxon;
  exemplar_identification?: ExemplarIdentification;
}

interface ActivityObservation extends Observation {
  identifications?: { hidden?: boolean; taxon: Taxon }[];
  obscured?: boolean;
  private_geojson?: unknown;
}

type ActivityCurrentUser = CurrentUser & {
  id?: number;
  roles: string[];
  canUnnominateIdentification?: ( item: ActivityItemModel ) => boolean;
};

interface ActivityConfig extends Config {
  currentUser?: ActivityCurrentUser;
  currentUserCanInteractWithResource: ( resource?: ActivityObservation ) => boolean;
  showHidden?: boolean;
}

interface CurrentUserID {
  taxon: { id: number };
  agreedTo?: { uuid: string };
}

export interface ActivityItemProps {
  observation?: ActivityObservation;
  item: ActivityItemModel;
  config: ActivityConfig;
  currentUserID?: CurrentUserID;
  linkTarget?: string;
  hideUserIcon?: boolean;
  hideAgree?: boolean;
  hideCompare?: boolean;
  hideDisagreement?: boolean;
  hideCategory?: boolean;
  hideMenu?: boolean;
  noTaxonLink?: boolean;
  inlineEditing?: boolean;
  onClickCompare?: (
    e: React.MouseEvent,
    taxon?: Taxon,
    observation?: ActivityObservation,
    options?: { currentUser?: ActivityCurrentUser }
  ) => boolean;
  // Handlers invoked directly by this component
  addID: ( taxon: Taxon, options?: { agreedTo?: ActivityItemModel } ) => void;
  editID: ( uuid: string, body?: string | null ) => void;
  editComment: ( uuid: string, body?: string | null ) => void;
  confirmDeleteID: ( uuid: string ) => void;
  performOrOpenConfirmationModal: (
    action: ( ) => void,
    options?: Record<string, unknown>
  ) => void;
  setFlaggingModalState: ( state: { item: ActivityItemModel; show: boolean } ) => void;
  voteIdentification: ( id: number, vote?: string ) => void;
  unvoteIdentification: ( id: number ) => void;
  // Handlers passed through to child menus
  deleteComment?: ( ...args: unknown[] ) => void;
  restoreID?: ( ...args: unknown[] ) => void;
  withdrawID?: ( ...args: unknown[] ) => void;
  trustUser?: ( ...args: unknown[] ) => void;
  untrustUser?: ( ...args: unknown[] ) => void;
  hideContent?: ( item: ActivityItemModel ) => void;
  unhideContent?: ( ...args: unknown[] ) => void;
  showHidden?: ( ...args: unknown[] ) => void;
  nominateIdentification?: ( ...args: unknown[] ) => void;
  unnominateIdentification?: ( ...args: unknown[] ) => void;
}

const ActivityItem = ( props: ActivityItemProps ) => {
  const {
    observation,
    item,
    config,
    deleteComment,
    restoreID,
    setFlaggingModalState,
    currentUserID,
    addID,
    editComment,
    editID,
    confirmDeleteID,
    voteIdentification,
    unvoteIdentification,
    inlineEditing,
    linkTarget,
    hideUserIcon,
    hideAgree,
    hideCompare,
    hideDisagreement,
    hideCategory,
    hideMenu,
    noTaxonLink,
    onClickCompare,
    trustUser,
    untrustUser,
    showHidden,
    hideContent,
    unhideContent,
    withdrawID,
    performOrOpenConfirmationModal,
    nominateIdentification,
    unnominateIdentification
  } = props;
  const [editing, setEditing] = useState( false );
  const [textareaContent, setTextareaContent] = useState<string | null | undefined>( item.body );
  const rootRef = useRef<HTMLDivElement>( null );

  const isID = !!item.taxon;

  useEffect( ( ) => {
    let targetHash = window.location.hash;
    let targetID;
    let action;
    const actionMatches = targetHash.match( /(.*):(.*)/ );
    if ( actionMatches !== null ) {
      targetHash = actionMatches[1];
      action = actionMatches[2];
    }
    if ( targetHash ) {
      targetID = _.replace( targetHash, /^#[a-z]+-/, "" );
    }
    if ( item?.uuid === targetID && action ) {
      if ( action === "flag" ) {
        performOrOpenConfirmationModal( ( ) => (
          setFlaggingModalState( { item, show: true } )
        ), {
          permitOwnerOf: item
        } );
        history.replaceState( window.history.state, "", window.location.href.replace( /:[^:]*$/, "" ) );
      } else if ( action === "hide" && hideContent && !item.hidden ) {
        hideContent( item );
        history.replaceState( window.history.state, "", window.location.href.replace( /:[^:]*$/, "" ) );
      }
    }
  }, [] );

  // Set up @mention autocomplete on any textarea rendered in edit mode.
  useEffect( ( ) => {
    if ( rootRef.current ) {
      $( "textarea", rootRef.current ).textcompleteUsers( );
    }
  } );

  const onEdit = ( e: React.SyntheticEvent ) => {
    if ( inlineEditing ) {
      e.preventDefault( );
      setEditing( !editing );
    }
  };

  /*
    Optional prop passed to child TextEditor, called on textarea change.
    Used here to keep ActivityItem state of content in sync with child TextEditors
    and parent Activity.
   */
  const changeHandler = ( content: string ) => setTextareaContent( content );

  const updateItem = ( ) => {
    if ( isID ) {
      editID( item.uuid, textareaContent );
    } else {
      editComment( item.uuid, textareaContent );
    }
    setEditing( !editing );
  };

  const deleteIdentification = ( ) => {
    confirmDeleteID( item.uuid );
    setEditing( !editing );
  };

  const editItemForm = ( ) => (
    <div className="form-group edit-comment-id">
      <TextEditor
        content={textareaContent}
        changeHandler={changeHandler}
        key={`comment-editor-${item.uuid}`}
        placeholder={isID ? I18n.t( "tell_us_why" ) : I18n.t( "leave_a_comment" )}
        textareaClassName="form-control"
        maxLength={5000}
        showCharsRemainingAt={4000}
        mentions
      />
      <div className="btn-group edit-form-btns">
        <button
          type="button"
          className="btn btn-primary btn-sm"
          onClick={( ) => updateItem( )}
        >
          { isID ? I18n.t( "save_identification" ) : I18n.t( "save_comment" ) }
        </button>
        <button
          type="button"
          className="btn btn-default btn-sm"
          onClick={( ) => setEditing( !editing )}
        >
          { I18n.t( "cancel" ) }
        </button>
        { isID && (
          <button
            type="button"
            className="btn btn-link btn-sm pull-right"
            onClick={( ) => deleteIdentification( )}
          >
            { I18n.t( "delete" ) }
          </button>
        ) }
      </div>
    </div>
  );

  // Is this an activity item for an identification that disagrees with a
  // taxon in a hidden identification? If so, it's not particularly important
  // to show that since that hidden ident isn't counting toward the Community
  // Taxon, and it might be important to hide the taxon if it was added to
  // cause harm
  const isDisagreementWithHiddenIdent = ( ) => {
    if ( !isID ) return false;
    if (
      !observation
      || !observation.identifications
      || observation.identifications.length === 0
    ) return false;
    if ( !item || !item.previous_observation_taxon_id || !item.disagreement ) return false;
    const hiddenIdents = observation.identifications.filter( i => i.hidden );
    const publicIdents = observation.identifications.filter( i => !i.hidden );
    if ( hiddenIdents.length === 0 ) return false;
    const selfAndAncestors = (
      i: { taxon: Taxon }
    ): ( number | number[] | undefined )[] => [i.taxon.id, i.taxon.ancestor_ids];
    const hiddenIdentTaxonIds = hiddenIdents.map( selfAndAncestors ).flat( Infinity );
    const publicIdentTaxonIds = publicIdents.map( selfAndAncestors ).flat( Infinity );
    // Basic logic here is that if this ident disagrees with a taxon from a
    // hidden identification that isn't among the remaining, non-hidden
    // idents, we should probably hide it
    return (
      hiddenIdentTaxonIds.includes( item.previous_observation_taxon_id )
      && !publicIdentTaxonIds.includes( item.previous_observation_taxon_id )
    );
  };

  const identificationHasNomination = ( ) => (
    !!( item.exemplar_identification && item.exemplar_identification.nominated_by_user )
  );

  const identificationVotes = ( ) => {
    const exemplar = item.exemplar_identification;
    if ( !identificationHasNomination( ) || !exemplar ) {
      return null;
    }

    const userCanVote = config?.currentUser?.canUnnominateIdentification?.( item );
    const votesFor: Vote[] = [];
    const votesAgainst: Vote[] = [];
    let userVotedFor: boolean | undefined;
    let userVotedAgainst: boolean | undefined;
    _.each( exemplar.votes, v => {
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
      userVotedFor
        ? unvoteIdentification( exemplar.id )
        : voteIdentification( exemplar.id )
    );
    const unvoteAction = () => (
      userVotedAgainst
        ? unvoteIdentification( exemplar.id )
        : voteIdentification( exemplar.id, "bad" )
    );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
    return (
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
        ) }
        { !_.isEmpty( votesFor ) && (
          <UsersPopover
            users={_.map( votesFor, "user" )}
            keyPrefix={`votes-against-${item.uuid}`}
            contents={( <span>{votesFor.length === 0 ? null : votesFor.length}</span> )}
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
        ) }
        { !_.isEmpty( votesAgainst ) && (
          <UsersPopover
            users={_.map( votesAgainst, "user" )}
            keyPrefix={`votes-against-${item.uuid}`}
            contents={( <span>{votesAgainst.length === 0 ? null : votesAgainst.length}</span> )}
          />
        ) }
      </div>
    );
  };

  if ( !item ) {
    return ( <div /> );
  }
  const { taxon } = item;
  const loggedIn = config?.currentUser;
  const userCanInteract = config?.currentUserCanInteractWithResource( observation );
  const canSeeHidden = config && config.currentUser && (
    config.currentUser.roles.indexOf( "admin" ) >= 0
    || config.currentUser.roles.indexOf( "curator" ) >= 0
    || config.currentUser.id === item.user.id
  );
  const viewerIsActor = config.currentUser && item.user.id === config.currentUser.id;
  let contents: React.ReactNode;
  let header: React.ReactNode[] = [];
  let className = "comment";
  if ( item.hidden && ( !canSeeHidden || !config.showHidden ) ) {
    return (
      <HiddenActivityItem
        canSeeHidden={canSeeHidden}
        hideUserIcon={hideUserIcon}
        isID={isID}
        item={item}
        showHidden={showHidden}
        viewerIsActor={viewerIsActor}
      />
    );
  }
  const userLink = (
    <UserLink
      className="user"
      config={config}
      noInativersary
      target={linkTarget}
      uniqueKey={`ActivityItem-${item.id}`}
      user={item.user}
    />
  );
  if ( isID && taxon ) {
    className = "identification";
    const buttons: React.ReactNode[] = [];
    let canAgree = false;
    let userAgreedToThis;
    if (
      loggedIn
      && item.current
      && item.firstDisplay
      && item.user.id !== config.currentUser?.id
      && ( item.taxon && item.taxon.is_active )
    ) {
      if ( currentUserID ) {
        canAgree = currentUserID.taxon.id !== taxon.id;
        userAgreedToThis = currentUserID.agreedTo && currentUserID.agreedTo.uuid === item.uuid;
      } else {
        canAgree = true;
      }
    }
    if ( userCanInteract && item.firstDisplay && !hideCompare ) {
      buttons.push( (
        <button
          key={`id-compare-${item.uuid}`}
          type="button"
          className="btn btn-default btn-sm"
          onClick={e => {
            if ( onClickCompare ) {
              return onClickCompare(
                e,
                taxon,
                observation,
                { currentUser: config.currentUser }
              );
            }
            return true;
          }}
        >
          <i className="fa fa-exchange" />
          {" "}
          {I18n.t( "compare" )}
        </button>
      ) );
    }
    if ( loggedIn && ( canAgree || userAgreedToThis ) && !hideAgree ) {
      buttons.push( (
        <button
          type="button"
          key={`id-agree-${item.uuid}`}
          className="btn btn-default btn-sm"
          onClick={() => {
            performOrOpenConfirmationModal( ( ) => {
              addID( taxon, { agreedTo: item } );
            } );
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
    header = [
      (
        <span
          dangerouslySetInnerHTML={{
            __html: item.taxon_change
              ? I18n.t( "inaturalist_updated_the_id_suggested_by_user", { user: ReactDOMServer.renderToString( userLink ) } )
              : I18n.t( "user_suggested_an_id", { user: ReactDOMServer.renderToString( userLink ) } )
          }}
          key={`ActivityItem-UserLink-${item.id}`}
        />
      )
    ];
    if ( item.disagreement && !isDisagreementWithHiddenIdent( ) ) {
      header.push( <span key={`ActivityItem-disagree-${item.id}`}>*</span> );
    }
    if ( !item.current ) {
      className = "withdrawn";
    }
    let idBody;
    if ( editing ) {
      idBody = editItemForm( );
    } else if ( item.body && _.trim( item.body ).length > 0 ) {
      idBody = <UserText text={item.body} className="id_body" />;
    }
    contents = (
      <div className="identification">
        <div className="taxon">
          {noTaxonLink ? taxonImageTag : (
            <a
              href={`/taxa/${taxon.id}`}
              target={linkTarget}
              rel={linkTarget === "_blank" ? "noopener noreferrer" : undefined}
            >
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
        {buttonDiv}
        {!_.isEmpty( idBody ) && (
          <div className="id-body-wrapper">
            { idBody }
          </div>
        )}
      </div>
    );
  } else if ( !item.hidden || canSeeHidden ) {
    header = [
      <span
        dangerouslySetInnerHTML={{
          __html: I18n.t( "user_commented", { user: ReactDOMServer.renderToString( userLink ) } )
        }}
        key={`ActivityItem-UserLink-${item.id}`}
      />
    ];
    contents = editing ? editItemForm( ) : ( <UserText text={item.body} /> );
  }
  const inativersary = (
    <Inativersary
      config={config}
      key={`ActivityItem-iNativersary-${item.uuid}`}
      user={item.user}
      uniqueKey={`ActivityItem-${item.uuid}`}
    />
  );
  if ( inativersary ) header.push( inativersary );
  const relativeTime = moment.parseZone( item.created_at ).fromNow();
  let panelClass: string | undefined;
  const headerItems: React.ReactNode[] = [];
  const unresolvedFlags = _.filter( item.flags || [], f => !f.resolved );
  if ( unresolvedFlags.length > 0 ) {
    panelClass = "flagged";
    headerItems.push(
      <span
        key={`flagged-${item.uuid}`}
        className="item-status"
        title={I18n.t( "flagged_" )}
      >
        <a
          href={`/${isID ? "identifications" : "comments"}/${item.uuid}/flags`}
          rel="nofollow noopener noreferrer"
          target="_blank"
        >
          <i className="fa fa-flag" />
          <span className="item-status-label">{` ${I18n.t( "flagged_" )}`}</span>
        </a>
      </span>
    );
  } else if ( item.category && item.current && !hideCategory ) {
    let idCategory: React.ReactNode;
    let idCategoryTooltipText;
    if ( item.category === "maverick" ) {
      panelClass = "maverick";
      idCategory = (
        <span
          key={`maverick-${item.uuid}`}
          className="item-status ident-category"
          title={I18n.t( "maverick" )}
        >
          <i className="fa fa-bolt" />
          <span className="item-status-label">{` ${I18n.t( "maverick" )}`}</span>
        </span>
      );
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.maverick" );
    } else if ( item.category === "improving" ) {
      panelClass = "improving";
      idCategory = (
        <span
          key={`improving-${item.uuid}`}
          className="item-status ident-category"
          title={I18n.t( "improving" )}
        >
          <i className="fa fa-trophy" />
          <span className="item-status-label">{` ${I18n.t( "improving" )}`}</span>
        </span>
      );
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.improving" );
    } else if ( item.category === "leading" ) {
      panelClass = "leading";
      idCategory = (
        <span
          key={`leading-${item.uuid}`}
          className="item-status ident-category"
          title={I18n.t( "leading" )}
        >
          <i className="icon-icn-leading-id" />
          <span className="item-status-label">{` ${I18n.t( "leading" )}`}</span>
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
      <span
        key={`ident-withdrawn-${item.uuid}`}
        className="item-status"
        title={I18n.t( "id_withdrawn" )}
      >
        <i className="fa fa-ban" />
        <span className="item-status-label">{` ${I18n.t( "id_withdrawn" )}`}</span>
      </span>
    );
  }
  if ( item.hidden ) {
    headerItems.push(
      <HiddenContentMessageContainer
        key={`hidden-tooltip-${item.uuid}`}
        item={item}
        itemType={isID ? "identifications" : "comments"}
        shrinkOnNarrowDisplays
      />
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
  const footers: Record<string, React.ReactNode> = {};

  if ( item.disagreement && !hideDisagreement && !isDisagreementWithHiddenIdent( ) ) {
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
    footers.disagreement = (
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
    footers.disagreement = (
      <span
        className="title_text"
        dangerouslySetInnerHTML={{
          __html: `* ${footerText}`
        }}
      />
    );
  }
  if ( identificationHasNomination( ) && item.exemplar_identification ) {
    footers.nomination = (
      <>
        <span
          className="footer-text"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "identification_tips.user_nominated_this_as_an_id_tip_html", {
              user: ReactDOMServer.renderToString( (
                <b>{item.exemplar_identification.nominated_by_user?.login}</b>
              ) )
            } )
          }}
        />
        <time
          className="time"
          dateTime={item.exemplar_identification.nominated_at}
          title={moment( item.exemplar_identification.nominated_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
        >
          {moment.parseZone( item.exemplar_identification.nominated_at ).fromNow( )}
        </time>
        {identificationVotes( )}
      </>
    );
  }
  const elementID = isID ? `activity_identification_${item.uuid}` : `activity_comment_${item.uuid}`;
  const itemURL = isID ? `/identifications/${item.uuid}` : `/comments/${item.uuid}`;
  let time = (
    <time
      className="time"
      dateTime={item.created_at}
      title={moment( item.created_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
    >
      <a
        href={itemURL}
        target={linkTarget}
        rel={linkTarget === "_blank" ? "noopener noreferrer" : undefined}
      >
        {relativeTime}
      </a>
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
  const menu = hideMenu ? null : (
    <ActivityItemMenu
      item={item}
      observation={observation}
      onEdit={( e: React.SyntheticEvent ) => onEdit( e )}
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
      performOrOpenConfirmationModal={performOrOpenConfirmationModal}
      nominateIdentification={nominateIdentification}
      unnominateIdentification={unnominateIdentification}
    />
  );
  return (
    <div id={elementID} ref={rootRef} className={`ActivityItem ${className} ${byClass}`}>
      { hideUserIcon ? null : (
        <div className="icon">
          {( !item.hidden || canSeeHidden || viewerIsActor ) && (
            <UserImage user={item.user} linkTarget={linkTarget} />
          )}
        </div>
      ) }
      <Panel className={`${panelClass}${item.api_status ? " loading" : ""}${hideUserIcon ? " no-user-icon" : ""}`}>
        <Panel.Heading>
          <Panel.Title>
            <span className="title_text">
              { header }
            </span>
            { headerItems }
            { time }
            { menu }
          </Panel.Title>
        </Panel.Heading>
        <Panel.Body>
          {taxonChange}
          <div className="contents">
            {contents}
          </div>
        </Panel.Body>
        { _.map( footers, ( footer, key ) => (
          <Panel.Footer key={`${elementID}-footer-${key}`}>
            {footer}
          </Panel.Footer>
        ) ) }
      </Panel>
    </div>
  );
};

export default ActivityItem;
