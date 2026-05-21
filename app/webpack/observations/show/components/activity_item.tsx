/* eslint-disable @typescript-eslint/no-explicit-any */
import React, { useEffect, useRef } from "react";
import HiddenActivityItem from "./hidden_activity_item";
import IdentificationItem from "./identification_item";
import CommentItem from "./comment_item";

export interface ActivityItemProps {
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

const ActivityItem = ( props: ActivityItemProps ) => {
  const {
    config,
    hideContent,
    item,
    performOrOpenConfirmationModal,
    setFlaggingModalState,
    showHidden
  } = props;
  const containerRef = useRef<HTMLDivElement>( null );

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
      targetID = targetHash.replace( /^#[a-z]+-/, "" );
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

  if ( !item ) return <div />;

  const currentUser = config?.currentUser;
  const isID = !!item.taxon;
  const canSeeHidden = currentUser && (
    currentUser.roles.indexOf( "admin" ) >= 0
    || currentUser.roles.indexOf( "curator" ) >= 0
    || currentUser.id === item.user.id
  );
  const viewerIsActor = !!( currentUser && item.user.id === currentUser.id );

  if ( item.hidden && ( !canSeeHidden || !config?.showHidden ) ) {
    return (
      <HiddenActivityItem
        canSeeHidden={canSeeHidden}
        hideUserIcon={props.hideUserIcon}
        isID={isID}
        item={item}
        showHidden={showHidden}
        viewerIsActor={viewerIsActor}
      />
    );
  }

  return isID ? (
    <IdentificationItem
      addID={props.addID}
      config={config}
      confirmDeleteID={props.confirmDeleteID}
      containerRef={containerRef}
      currentUserID={props.currentUserID}
      deleteComment={props.deleteComment}
      editComment={props.editComment}
      editID={props.editID}
      hideAgree={props.hideAgree}
      hideCategory={props.hideCategory}
      hideCompare={props.hideCompare}
      hideContent={hideContent}
      hideDisagreement={props.hideDisagreement}
      hideMenu={props.hideMenu}
      hideUserIcon={props.hideUserIcon}
      inlineEditing={props.inlineEditing}
      item={item}
      linkTarget={props.linkTarget}
      noTaxonLink={props.noTaxonLink}
      observation={props.observation}
      onClickCompare={props.onClickCompare}
      performOrOpenConfirmationModal={performOrOpenConfirmationModal}
      restoreID={props.restoreID}
      setFlaggingModalState={setFlaggingModalState}
      trustUser={props.trustUser}
      unhideContent={props.unhideContent}
      untrustUser={props.untrustUser}
      voteIdentification={props.voteIdentification}
      unvoteIdentification={props.unvoteIdentification}
      withdrawID={props.withdrawID}
      nominateIdentification={props.nominateIdentification}
      unnominateIdentification={props.unnominateIdentification}
    />
  ) : (
    <CommentItem
      config={config}
      containerRef={containerRef}
      deleteComment={props.deleteComment}
      editComment={props.editComment}
      hideContent={hideContent}
      hideMenu={props.hideMenu}
      hideUserIcon={props.hideUserIcon}
      inlineEditing={props.inlineEditing}
      item={item}
      linkTarget={props.linkTarget}
      observation={props.observation}
      performOrOpenConfirmationModal={performOrOpenConfirmationModal}
      setFlaggingModalState={setFlaggingModalState}
      trustUser={props.trustUser}
      unhideContent={props.unhideContent}
      untrustUser={props.untrustUser}
    />
  );
};

export default ActivityItem;
