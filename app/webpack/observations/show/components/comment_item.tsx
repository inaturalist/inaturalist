/* eslint-disable react/no-danger */
/* eslint-disable @typescript-eslint/no-explicit-any */
import React, { useState } from "react";
import ReactDOMServer from "react-dom/server";
import _ from "lodash";
import moment from "moment-timezone";
import UserText from "../../../shared/components/user_text";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";
import Inativersary from "../../../shared/components/inativersary";
import ActivityItemMenu from "./activity_item_menu";
import TextEditor from "../../../shared/components/text_editor";
import HiddenContentMessageContainer from "../../../shared/containers/hidden_content_message_container";

export interface CommentItemProps {
  config?: Record<string, any>;
  containerRef: React.RefObject<HTMLDivElement>;
  deleteComment?: ( ...args: any[] ) => void;
  editComment?: ( uuid: string, body: string ) => void;
  hideContent?: ( item: object ) => void;
  hideMenu?: boolean;
  hideUserIcon?: boolean;
  inlineEditing?: boolean;
  item: Record<string, any>;
  linkTarget?: string;
  observation?: Record<string, any>;
  performOrOpenConfirmationModal?: ( callback: ( ) => void, options?: object ) => void;
  setFlaggingModalState?: ( state: object ) => void;
  trustUser?: ( ...args: any[] ) => void;
  unhideContent?: ( ...args: any[] ) => void;
  untrustUser?: ( ...args: any[] ) => void;
}

const CommentItem = ( {
  config,
  containerRef,
  deleteComment,
  editComment,
  hideContent,
  hideMenu,
  hideUserIcon,
  inlineEditing,
  item,
  linkTarget,
  observation,
  performOrOpenConfirmationModal,
  setFlaggingModalState,
  trustUser,
  unhideContent,
  untrustUser
}: CommentItemProps ) => {
  const [editing, setEditing] = useState( false );
  const [textareaContent, setTextareaContent] = useState( item.body || "" );

  const onEdit = ( e: React.MouseEvent ) => {
    if ( inlineEditing ) {
      e.preventDefault( );
      setEditing( prev => !prev );
    }
  };

  const updateItem = ( ) => {
    editComment?.( item.uuid, textareaContent );
    setEditing( false );
  };

  const editItemForm = ( ) => (
    <div className="form-group edit-comment-id">
      <TextEditor
        content={textareaContent}
        changeHandler={( content: string ) => setTextareaContent( content )}
        key={`comment-editor-${item.uuid}`}
        placeholder={I18n.t( "leave_a_comment" )}
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
          { I18n.t( "save_comment" ) }
        </button>
        <button
          type="button"
          className="btn btn-default btn-sm"
          onClick={( ) => setEditing( false )}
        >
          { I18n.t( "cancel" ) }
        </button>
      </div>
    </div>
  );

  const currentUser = config?.currentUser;
  const viewerIsActor = !!( currentUser && item.user.id === currentUser.id );
  const canSeeHidden = currentUser && (
    currentUser.roles.indexOf( "admin" ) >= 0
    || currentUser.roles.indexOf( "curator" ) >= 0
    || currentUser.id === item.user.id
  );

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

  const header: React.ReactNode[] = [
    <span
      dangerouslySetInnerHTML={{
        __html: I18n.t( "user_commented", {
          user: ReactDOMServer.renderToString( userLink )
        } )
      }}
      key={`ActivityItem-UserLink-${item.id}`}
    />,
    <Inativersary
      config={config}
      key={`ActivityItem-iNativersary-${item.uuid}`}
      user={item.user}
      uniqueKey={`ActivityItem-${item.uuid}`}
    />
  ];

  let panelClass: string | undefined;
  const headerItems: React.ReactNode[] = [];
  const unresolvedFlags = _.filter( item.flags || [], ( f: any ) => !f.resolved );
  if ( unresolvedFlags.length > 0 ) {
    panelClass = "flagged";
    headerItems.push(
      <span key={`flagged-${item.uuid}`} className="item-status">
        <a
          href={`/comments/${item.uuid}/flags`}
          rel="nofollow noopener noreferrer"
          target="_blank"
        >
          <i className="fa fa-flag" />
          { " " }
          { I18n.t( "flagged_" ) }
        </a>
      </span>
    );
  }

  if ( item.hidden ) {
    headerItems.push(
      <HiddenContentMessageContainer
        key={`hidden-tooltip-${item.uuid}`}
        item={item}
        itemType="comments"
        shrinkOnNarrowDisplays
      />
    );
  }

  const elementID = `activity_comment_${item.uuid}`;
  const relativeTime = moment.parseZone( item.created_at ).fromNow( );
  let time: React.ReactNode = (
    <time
      className="time"
      dateTime={item.created_at}
      title={moment( item.created_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
    >
      <a
        href={`/comments/${item.uuid}`}
        target={linkTarget}
        rel={linkTarget === "_blank" ? "noopener noreferrer" : undefined}
      >
        { relativeTime }
      </a>
    </time>
  );
  if ( observation?.obscured && !observation.private_geojson ) {
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
      setFlaggingModalState={setFlaggingModalState}
      linkTarget={linkTarget}
      trustUser={trustUser}
      untrustUser={untrustUser}
      hideContent={hideContent}
      unhideContent={unhideContent}
      performOrOpenConfirmationModal={performOrOpenConfirmationModal}
    />
  );

  const byClass = viewerIsActor ? "by-current-user" : "by-someone-else";
  const contents = editing ? editItemForm( ) : ( <UserText text={item.body} /> );

  return (
    <div id={elementID} className={`ActivityItem comment ${byClass}`} ref={containerRef}>
      { hideUserIcon ? null : (
        <div className="icon">
          { ( !item.hidden || canSeeHidden || viewerIsActor ) && (
            <UserImage user={item.user} linkTarget={linkTarget} />
          ) }
        </div>
      ) }
      <div
        className={`panel panel-default${panelClass ? ` ${panelClass}` : ""}${item.api_status ? " loading" : ""}${hideUserIcon ? " no-user-icon" : ""}`}
      >
        <div className="panel-heading">
          <div className="panel-title">
            <span className="title_text">{ header }</span>
            { headerItems }
            { time }
            { menu }
          </div>
        </div>
        <div className="panel-body">
          <div className="contents">{ contents }</div>
        </div>
      </div>
    </div>
  );
};

export default CommentItem;
