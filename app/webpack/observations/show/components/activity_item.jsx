import React, { PropTypes } from "react";
import ReactDOMServer from "react-dom/server";
import _ from "lodash";
import { Panel } from "react-bootstrap";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";
import UserImage from "../../identify/components/user_image";
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
      target={linkTarget}
    >
      { item.user.login }
    </a>
  );
  if ( isID ) {
    let buttons = [];
    let canAgree = false;
    let userAgreedToThis;
    if ( item.current && firstDisplay && item.user.id !== config.currentUser.id ) {
      if ( currentUserID ) {
        canAgree = util.taxaDissimilar( currentUserID.taxon, taxon );
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
        <div className="taxon">
          <a href={ `/taxa/${taxon.id}` }>
            { taxonImageTag }
          </a>
          <SplitTaxon
            taxon={ taxon }
            url={ `/taxa/${taxon.id}` }
            noParens
            target={linkTarget}
          />
        </div>
        { buttonDiv }
        { item.body && ( <UserText text={ item.body } className="id_body" /> ) }
      </div>
    );
  } else {
    header = I18n.t( "user_commented", { user: ReactDOMServer.renderToString( userLink ) } );
    contents = ( <UserText text={ item.body } /> );
  }
  const relativeTime = moment.parseZone( item.created_at ).fromNow( );
  let panelClass;
  let statuses = [];
  const unresolvedFlags = _.filter( item.flags || [], f => !f.resolved );
  if ( unresolvedFlags.length > 0 ) {
    panelClass = "flagged";
    statuses.push( ( <span key={ `flagged-${item.id}` } className="item-status">
      <i className="fa fa-flag" /> { I18n.t( "flagged_" ) }
    </span> ) );
  } else if ( item.category && item.current ) {
    if ( item.category === "maverick" ) {
      panelClass = "maverick";
      statuses.push( ( <span key={ `maverick-${item.id}` } className="item-status">
        <i className="fa fa-bolt" /> { I18n.t( "maverick" ) }
      </span> ) );
    } else if ( item.category === "improving" ) {
      panelClass = "improving";
      statuses.push( ( <span key={ `improving-${item.id}` } className="item-status">
        <i className="fa fa-trophy" /> { I18n.t( "improving" ) }
      </span> ) );
    } else if ( item.category === "leading" ) {
      panelClass = "improving";
      statuses.push( ( <span key={ `leading-${item.id}` } className="item-status">
        <i className="fa fa-trophy" /> { I18n.t( "leading" ) }
      </span> ) );
    }
  }
  if ( item.taxon_change_id ) {
    const type = _.snakeCase( item.taxon_change_type );
    statuses.push( ( <span key={ `change-${item.id}` } className="item-status">
      { I18n.t( "added_as_a_part_of" ) } <a
        href={ `/taxon_changes/${item.taxon_change_id}` }
        target={linkTarget}
      >
        <i className="fa fa-refresh" /> { I18n.t( type ) }
      </a>
    </span> ) );
  }
  return (
    <div className={ `ActivityItem ${className}` }>
      <div className="icon">
        <UserImage user={ item.user } />
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
          <span className="time">
            { relativeTime }
          </span>
          { statuses }
        </span>
        )}
      >
        { contents }
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
