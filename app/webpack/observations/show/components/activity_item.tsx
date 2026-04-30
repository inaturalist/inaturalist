/* eslint-disable react/no-danger */
import React, { useEffect, useRef, useState } from "react";
import ReactDOMServer from "react-dom/server";
import _ from "lodash";
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

// TODO: This file could benefit from reducting conditional logic and more explicit ActivityItem
// types - perhaps even splitting into multiple components.

interface ActivityItemProps {
  addID?: ( taxon: object, options?: object ) => void;
  config?: Record<string, any>;
  confirmDeleteID?: ( uuid: string ) => void;
  currentUserID?: Record<string, any>;
  deleteComment?: ( ...args: any[] ) => void;
  editComment?: ( uuid: string, body: string ) => void;
  editID?: ( uuid: string, body: string ) => void;
  hideAgree?: boolean;
  hideCategory?: boolean;
  hideCompare?: boolean;
  hideContent?: ( item: object ) => void;
  hideDisagreement?: boolean;
  hideMenu?: boolean;
  hideUserIcon?: boolean;
  inlineEditing?: boolean;
  item?: Record<string, any>;
  linkTarget?: string;
  noTaxonLink?: boolean;
  observation?: Record<string, any>;
  onClickCompare?: (
    e: React.MouseEvent,
    taxon: object,
    observation: object,
    options: object
  ) => void;
  performOrOpenConfirmationModal?: ( callback: ( ) => void, options?: object ) => void;
  restoreID?: ( ...args: any[] ) => void;
  setFlaggingModalState?: ( state: object ) => void;
  showHidden?: ( ...args: any[] ) => void;
  trustUser?: ( ...args: any[] ) => void;
  unhideContent?: ( ...args: any[] ) => void;
  untrustUser?: ( ...args: any[] ) => void;
  withdrawID?: ( ...args: any[] ) => void;
  nominateIdentification?: ( ...args: any[] ) => void;
  unnominateIdentification?: ( ...args: any[] ) => void;
  voteIdentification?: ( id: string, flag?: string ) => void;
  unvoteIdentification?: ( id: string ) => void;
}

const ActivityItem = ( {
  observation,
  item,
  config,
  deleteComment,
  restoreID,
  setFlaggingModalState,
  currentUserID,
  addID,
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
  unnominateIdentification,
  inlineEditing,
  editComment,
  editID,
  confirmDeleteID,
  voteIdentification,
  unvoteIdentification
}: ActivityItemProps ) => {
  const isID = !!item?.taxon;
  const [editing, setEditing] = useState( false );
  const [textareaContent, setTextareaContent] = useState( item?.body || "" );
  const [showVisionPopover, setShowVisionPopover] = useState( false );
  const containerRef = useRef<HTMLDivElement>( null );
  const visionPopoverRef = useRef<HTMLSpanElement>( null );

  useEffect( ( ) => {
    let targetHash = window.location.hash;
    let targetID: string | undefined;
    let action: string | undefined;
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
        performOrOpenConfirmationModal?.( ( ) => {
          setFlaggingModalState?.( { item, show: true } );
        }, { permitOwnerOf: item } );
        history.replaceState(
          window.history.state,
          "",
          window.location.href.replace( /:[^:]*$/, "" )
        );
      } else if ( action === "hide" && hideContent && item && !item.hidden ) {
        hideContent( item );
        history.replaceState(
          window.history.state,
          "",
          window.location.href.replace( /:[^:]*$/, "" )
        );
      }
    }
  }, [] );

  useEffect( ( ) => {
    if ( containerRef.current ) {
      ( $( "textarea", containerRef.current ) as any ).textcompleteUsers( );
    }
  } );

  useEffect( ( ) => {
    if ( !showVisionPopover ) return ( ) => { };
    const handleClickOutside = ( e: MouseEvent ) => {
      if ( visionPopoverRef.current && !visionPopoverRef.current.contains( e.target as Node ) ) {
        setShowVisionPopover( false );
      }
    };
    document.addEventListener( "click", handleClickOutside );
    return ( ) => document.removeEventListener( "click", handleClickOutside );
  }, [showVisionPopover] );

  const changeHandler = ( content: string ) => setTextareaContent( content );

  const updateItem = ( ) => {
    if ( isID ) {
      editID?.( item!.uuid, textareaContent );
    } else {
      editComment?.( item!.uuid, textareaContent );
    }
    setEditing( false );
  };

  const deleteIdentification = ( ) => {
    confirmDeleteID?.( item!.uuid );
    setEditing( false );
  };

  const onEdit = ( e: React.MouseEvent ) => {
    if ( inlineEditing ) {
      e.preventDefault( );
      setEditing( prev => !prev );
    }
  };

  const isDisagreementWithHiddenIdent = ( ) => {
    if ( !isID ) return false;
    if (
      !observation
      || !observation.identifications
      || observation.identifications.length === 0
    ) return false;
    if ( !item || !item.previous_observation_taxon_id || !item.disagreement ) return false;
    const hiddenIdents = observation.identifications.filter( ( i: any ) => i.hidden );
    const publicIdents = observation.identifications.filter( ( i: any ) => !i.hidden );
    if ( hiddenIdents.length === 0 ) return false;
    const selfAndAncestors = ( i: any ) => [i.taxon.id, i.taxon.ancestor_ids];
    const hiddenIdentTaxonIds = hiddenIdents.map( selfAndAncestors ).flat( Infinity );
    const publicIdentTaxonIds = publicIdents.map( selfAndAncestors ).flat( Infinity );
    return (
      hiddenIdentTaxonIds.includes( item.previous_observation_taxon_id )
      && !publicIdentTaxonIds.includes( item.previous_observation_taxon_id )
    );
  };

  const identificationHasNomination = ( ) => (
    item?.exemplar_identification && item.exemplar_identification.nominated_by_user
  );

  const identificationVotes = ( ) => {
    if ( !identificationHasNomination( ) ) return null;

    const votesFor: any[] = [];
    const votesAgainst: any[] = [];
    let userVotedFor: boolean | undefined;
    let userVotedAgainst: boolean | undefined;
    _.each( item!.exemplar_identification.votes, ( v: any ) => {
      if ( v.vote_flag === true ) {
        votesFor.push( v );
      } else if ( v.vote_flag === false ) {
        votesAgainst.push( v );
      }
      if ( v.user?.id === config?.currentUser?.id ) {
        userVotedFor = ( v.vote_flag === true );
        userVotedAgainst = ( v.vote_flag === false );
      }
    } );
    const voteAction = ( ) => (
      userVotedFor
        ? unvoteIdentification?.( item!.exemplar_identification.id )
        : voteIdentification?.( item!.exemplar_identification.id )
    );
    const unvoteAction = ( ) => (
      userVotedAgainst
        ? unvoteIdentification?.( item!.exemplar_identification.id )
        : voteIdentification?.( item!.exemplar_identification.id, "bad" )
    );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
    return (
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
            keyPrefix={`votes-for-${item!.uuid}`}
            contents={( <span>{votesFor.length}</span> )}
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
            keyPrefix={`votes-against-${item!.uuid}`}
            contents={( <span>{votesAgainst.length}</span> )}
          />
        ) }
      </div>
    );
  };

  const editItemForm = ( ) => (
    <div className="form-group edit-comment-id">
      <TextEditor
        content={textareaContent}
        changeHandler={changeHandler}
        key={`comment-editor-${item!.uuid}`}
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
          onClick={( ) => setEditing( false )}
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

  if ( !item ) {
    return <div />;
  }

  const { taxon } = item;
  const currentUser = config?.currentUser;
  const loggedIn = !!currentUser;
  const userCanInteract = config?.currentUserCanInteractWithResource( observation );
  const canSeeHidden = config && config.currentUser && (
    config.currentUser.roles.indexOf( "admin" ) >= 0
    || config.currentUser.roles.indexOf( "curator" ) >= 0
    || config.currentUser.id === item.user.id
  );
  const viewerIsActor = currentUser && item.user.id === currentUser.id;

  if ( item.hidden && ( !canSeeHidden || !config?.showHidden ) ) {
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

  let contents: React.ReactNode = null;
  let header: React.ReactNode[] = [];
  let className = "comment";

  if ( isID ) {
    className = "identification";
    const buttons = [];
    let canAgree = false;
    let userAgreedToThis;
    if (
      loggedIn
      && item.current
      && item.firstDisplay
      && item.user.id !== currentUser.id
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
              return onClickCompare( e, taxon, observation!, { currentUser } );
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
            performOrOpenConfirmationModal?.( ( ) => {
              addID?.( taxon, { agreedTo: item } );
            } );
          }}
          disabled={userAgreedToThis}
        >
          {userAgreedToThis ? ( <div className="loading_spinner" /> ) : ( <i className="fa fa-check" /> )}
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
              ? I18n.t( "inaturalist_updated_the_id_suggested_by_user", {
                user: ReactDOMServer.renderToString( userLink )
              } )
              : I18n.t( "user_suggested_an_id", {
                user: ReactDOMServer.renderToString( userLink )
              } )
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
    let idBody: React.ReactNode;
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
            user={currentUser}
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
          __html: I18n.t( "user_commented", {
            user: ReactDOMServer.renderToString( userLink )
          } )
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
  header.push( inativersary );

  const relativeTime = moment.parseZone( item.created_at ).fromNow( );
  let panelClass: string | undefined;
  const headerItems: React.ReactNode[] = [];
  const unresolvedFlags = _.filter( item.flags || [], ( f: any ) => !f.resolved );
  if ( unresolvedFlags.length > 0 ) {
    panelClass = "flagged";
    headerItems.push(
      <span key={`flagged-${item.uuid}`} className="item-status">
        <a
          href={`/${isID ? "identifications" : "comments"}/${item.uuid}/flags`}
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
    let idCategory: React.ReactNode;
    let idCategoryTooltipText: string | undefined;
    if ( item.category === "maverick" ) {
      panelClass = "maverick";
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.maverick" );
      idCategory = (
        <span
          key={`maverick-${item.uuid}`}
          className="item-status ident-category"
          title={idCategoryTooltipText}
        >
          <i className="fa fa-bolt" />
          {" "}
          {I18n.t( "maverick" )}
        </span>
      );
    } else if ( item.category === "improving" ) {
      panelClass = "improving";
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.improving" );
      idCategory = (
        <span
          key={`improving-${item.uuid}`}
          className="item-status ident-category"
          title={idCategoryTooltipText}
        >
          <i className="fa fa-trophy" />
          {" "}
          {I18n.t( "improving" )}
        </span>
      );
    } else if ( item.category === "leading" ) {
      panelClass = "leading";
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.leading" );
      idCategory = (
        <span
          key={`leading-${item.uuid}`}
          className="item-status ident-category"
          title={idCategoryTooltipText}
        >
          <i className="icon-icn-leading-id" />
          {" "}
          {I18n.t( "leading" )}
        </span>
      );
    }
    if ( idCategory ) {
      headerItems.push( idCategory );
    }
  }

  if ( item.vision ) {
    headerItems.push(
      <span
        key={`intent-vision-${item.uuid}`}
        ref={visionPopoverRef}
        className="vision-status"
        style={{ position: "relative" }}
      >
        <button
          type="button"
          className="btn btn-nostyle"
          aria-label={I18n.t( "computer_vision_suggestion" )}
          onClick={e => {
            e.stopPropagation( );
            setShowVisionPopover( prev => !prev );
          }}
        >
          <i className="icon-sparkly-label" />
        </button>
        { showVisionPopover && (
          <div className="popover top in" role="tooltip">
            <div className="arrow" />
            <h3 className="popover-title">{I18n.t( "computer_vision_suggestion" )}</h3>
            <div className="popover-content">{I18n.t( "computer_vision_suggestion_desc" )}</div>
          </div>
        ) }
      </span>
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

  let taxonChange: React.ReactNode;
  if ( item.taxon_change ) {
    const taxonChangeLinkAttrs = {
      url: `/taxon_changes/${item.taxon_change.id}`,
      target: linkTarget,
      class: "linky"
    };
    let taxonChangeLink: string;
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
        <span dangerouslySetInnerHTML={{ __html: taxonChangeLink }} />
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
        user={currentUser}
      />
    );
    const footerText = I18n.t( "user_disagrees_this_is_taxon", {
      user: ReactDOMServer.renderToString( userLink ),
      taxon: ReactDOMServer.renderToString( previousTaxonLink )
    } );
    footers.disagreement = (
      <span
        className="title_text"
        dangerouslySetInnerHTML={{ __html: `* ${footerText}` }}
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
        dangerouslySetInnerHTML={{ __html: `* ${footerText}` }}
      />
    );
  }
  if ( currentUser?.canViewHelpfulIDTips( ) && identificationHasNomination( ) ) {
    footers.nomination = (
      <>
        <span className="footer-text">
          <b>{item.exemplar_identification.nominated_by_user.login}</b>
          &nbsp;nominated this as an ID tip
        </span>
        <time
          className="time"
          dateTime={item.exemplar_identification.nominated_at}
          title={moment( item.exemplar_identification.nominated_at ).format(
            I18n.t( "momentjs.datetime_with_zone" )
          )}
        >
          {moment.parseZone( item.exemplar_identification.nominated_at ).fromNow( )}
        </time>
        {identificationVotes( )}
      </>
    );
  }

  const elementID = isID ? `activity_identification_${item.uuid}` : `activity_comment_${item.uuid}`;
  const itemURL = isID ? `/identifications/${item.uuid}` : `/comments/${item.uuid}`;
  let time: React.ReactNode = (
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
  if ( observation && observation.obscured && !observation.private_geojson ) {
    const viewerCreatedItem = currentUser && item.user && item.user.id === currentUser.id;
    if ( !viewerCreatedItem ) {
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
      onEdit={e => onEdit( e )}
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
    <div id={elementID} className={`ActivityItem ${className} ${byClass}`} ref={containerRef}>
      { hideUserIcon ? null : (
        <div className="icon">
          {( !item.hidden || canSeeHidden || viewerIsActor ) && (
            <UserImage user={item.user} linkTarget={linkTarget} />
          )}
        </div>
      ) }
      <div
        className={`panel panel-default${panelClass ? ` ${panelClass}` : ""}${item.api_status ? " loading" : ""}${hideUserIcon ? " no-user-icon" : ""}`}
      >
        <div className="panel-heading">
          <div className="panel-title">
            <span className="title_text">
              { header }
            </span>
            { headerItems }
            { time }
            { menu }
          </div>
        </div>
        <div className="panel-body">
          {taxonChange}
          <div className="contents">
            {contents}
          </div>
        </div>
        { _.map( footers, ( footer, key ) => (
          <div key={`${elementID}-footer-${key}`} className="panel-footer">
            {footer}
          </div>
        ) ) }
      </div>
    </div>
  );
};

export default ActivityItem;
