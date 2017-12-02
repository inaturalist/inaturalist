import React, { PropTypes } from "react";
import ReactDOMServer from "react-dom/server";
import _ from "lodash";
import { OverlayTrigger, Panel, Tooltip } from "react-bootstrap";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";
import UserImage from "../../../shared/components/user_image";
import ActivityItemMenu from "./activity_item_menu";
import util from "../util";

const ActivityItem = ( { observation, item, config, deleteComment, deleteID, firstDisplay,
                         restoreID, setFlaggingModalState, currentUserID, addID, linkTarget,
                         hideCompare } ) => {
  if ( !item ) { return ( <div /> ); }
  const taxon = item.taxon;
  const isID = !!taxon;
  const loggedIn = config && config.currentUser;
  let contents;
  let header;
  let className;
  const userLink = (
    <a
      className="user"
      href={ `/people/${item.user.login}` }
      target={ linkTarget }
    >
      { item.user.login }
    </a>
  );
  if ( isID ) {
    let buttons = [];
    let canAgree = false;
    let userAgreedToThis;
    if ( loggedIn && item.current && firstDisplay && item.user.id !== config.currentUser.id ) {
      if ( currentUserID ) {
        canAgree = currentUserID.taxon.id !== taxon.id;
        userAgreedToThis = currentUserID.agreedTo && currentUserID.agreedTo.id === item.id;
      } else {
        canAgree = true;
      }
    }
    if ( firstDisplay && !hideCompare ) {
      const compareTaxonID = taxon.rank_level <= 10 ?
        taxon.ancestor_ids[taxon.ancestor_ids - 2] : taxon.id;
      buttons.push( (
        <a
          key={ `id-compare-${item.id}` }
          href={ `/observations/identotron?observation_id=${observation.id}&taxon=${compareTaxonID}` }
        >
          <button className="btn btn-default btn-sm">
            <i className="fa fa-exchange" /> { I18n.t( "compare" ) }
          </button>
        </a>
      ) );
    }
    if ( loggedIn && ( canAgree || userAgreedToThis ) ) {
      buttons.push( (
        <button
          key={ `id-agree-${item.id}` }
          className="btn btn-default btn-sm"
          onClick={ () => { addID( taxon, { agreedTo: item } ); } }
          disabled={ userAgreedToThis }
        >
          { userAgreedToThis ? ( <div className="loading_spinner" /> ) :
            ( <i className="fa fa-check" /> ) } { I18n.t( "agree_" ) }
        </button>
      ) );
    }
    const buttonDiv = ( <div className="buttons">
      <div className="btn-space">
        { buttons }
      </div>
    </div> );
    const taxonImageTag = util.taxonImage( taxon );
    header = I18n.t( "user_suggested_an_id", { user: ReactDOMServer.renderToString( userLink ) } );
    if ( !item.current ) { className = "withdrawn"; }
    contents = (
      <div className="identification">
        { buttonDiv }
        <div className="taxon">
          <a href={ `/taxa/${taxon.id}` } target={ linkTarget }>
            { taxonImageTag }
          </a>
          <SplitTaxon
            taxon={ taxon }
            url={ `/taxa/${taxon.id}` }
            noParens
            target={ linkTarget }
            showMemberGroup
          />
        </div>
        { item.body && ( <UserText text={ item.body } className="id_body" /> ) }
      </div>
    );
  } else {
    header = I18n.t( "user_commented", { user: ReactDOMServer.renderToString( userLink ) } );
    contents = ( <UserText text={ item.body } /> );
  }
  const relativeTime = moment.parseZone( item.created_at ).fromNow( );
  let panelClass;
  let status;
  const unresolvedFlags = _.filter( item.flags || [], f => !f.resolved );
  if ( unresolvedFlags.length > 0 ) {
    panelClass = "flagged";
    status = ( <span key={ `flagged-${item.id}` } className="item-status">
      <a
        href={`/${isID ? "identifications" : "comments"}/${item.id}/flags`}
        rel="nofollow"
        target="_blank"
      >
        <i className="fa fa-flag" /> { I18n.t( "flagged_" ) }
      </a>
    </span> );
  } else if ( item.category && item.current ) {
    let idCategory;
    let idCategoryTooltipText;
    if ( item.category === "maverick" ) {
      panelClass = "maverick";
      idCategory = ( <span key={ `maverick-${item.id}` } className="item-status">
        <i className="fa fa-bolt" /> { I18n.t( "maverick" ) }
      </span> );
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.maverick" );
    } else if ( item.category === "improving" ) {
      panelClass = "improving";
      idCategory = ( <span key={ `improving-${item.id}` } className="item-status">
        <i className="fa fa-trophy" /> { I18n.t( "improving" ) }
      </span> );
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.improving" );
    } else if ( item.category === "leading" ) {
      panelClass = "leading";
      idCategory = ( <span key={ `leading-${item.id}` } className="item-status">
        <i className="icon-icn-leading-id" /> { I18n.t( "leading" ) }
      </span> );
      idCategoryTooltipText = I18n.t( "id_categories.tooltips.leading" );
    }
    if ( idCategory ) {
      status = (
        <OverlayTrigger
          container={ $( "#wrapper.bootstrap" ).get( 0 ) }
          placement="top"
          delayShow={ 200 }
          overlay={ (
            <Tooltip id={`tooltip-${item.id}`}>
              { idCategoryTooltipText }
            </Tooltip>
          ) }
        >
          { idCategory }
        </OverlayTrigger>
      );
    }
  }
  let taxonChange;
  if ( item.taxon_change ) {
    const type = _.snakeCase( item.taxon_change.type );
    taxonChange = ( <div className="taxon-change">
      <i className="fa fa-refresh" /> { I18n.t( "this_id_was_added_due_to_a" ) } <a
        href={ `/taxon_changes/${item.taxon_change.id}` }
        target={ linkTarget }
        className="linky"
      >
         { _.startCase( I18n.t( type ) ) }
      </a>
    </div> );
  }
  const viewerIsActor = config.currentUser && item.user.id === config.currentUser.id;
  const byClass = viewerIsActor ? "by-current-user" : "by-someone-else";
  let disagreement;
  if ( item.disagreement ) {
    disagreement = (
      <span className="badge pull-right">
        Disagreement with taxon { item.previous_observation_taxon_id }
      </span>
    );
  }
  return (
    <div className={ `ActivityItem ${className} ${byClass}` }>
      <div className="icon">
        <UserImage user={ item.user } linkTarget={ linkTarget } />
      </div>
      <Panel className={ panelClass } header={(
        <span>
          <span className="title_text" dangerouslySetInnerHTML={ { __html: header } } />
          <ActivityItemMenu
            item={ item }
            config={ config }
            deleteComment={ deleteComment }
            deleteID={ deleteID }
            restoreID={ restoreID }
            setFlaggingModalState={ setFlaggingModalState }
            linkTarget={linkTarget}
          />
          <time
            className="time"
            dateTime={ item.created_at }
            title={ moment( item.created_at ).format( "LLL" ) }
          >
            { relativeTime }
          </time>
          { status }
          { disagreement }
        </span>
        )}
      >
        { taxonChange }
        <div className="contents">
          { contents }
        </div>
      </Panel>
    </div>
  );
};

ActivityItem.propTypes = {
  item: PropTypes.object,
  config: PropTypes.object,
  currentUserID: PropTypes.object,
  observation: PropTypes.object,
  addID: PropTypes.func,
  deleteComment: PropTypes.func,
  deleteID: PropTypes.func,
  restoreID: PropTypes.func,
  firstDisplay: PropTypes.bool,
  setFlaggingModalState: PropTypes.func,
  linkTarget: PropTypes.string,
  hideCompare: PropTypes.bool
};

export default ActivityItem;
