import React, { PropTypes } from "react";
import { Panel } from "react-bootstrap";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../identify/components/user_image";
import ActivityItemMenu from "./activity_item_menu";


const ActivityItem = ( { item, config, deleteComment, deleteID, restoreID } ) => {
  if ( !item ) { return ( <div /> ); }
  let taxonImageTag;
  const taxon = item.taxon;
  const isID = !!taxon;
  let contents;
  let header;
  let className;
  const userLink = (
    <a href={ `/people/${item.user.login}` }>{ item.user.login }</a>
  );
  // TODO: mentions
  if ( isID ) {
    if ( taxon && item.taxon.defaultPhoto ) {
      taxonImageTag = (
        <img src={ taxon.defaultPhoto.photoUrl( ) } className="taxon-image" />
      );
    } else if ( taxon.iconic_taxon_name ) {
      taxonImageTag = (
        <i
          className={`taxon-image icon icon-iconic-${
            taxon.iconic_taxon_name.toLowerCase( )}`}
        >
        </i>
      );
    } else {
      taxonImageTag = <i className="taxon-image icon icon-iconic-unknown"></i>;
    }
    header = "suggested an ID";
    if ( !item.current ) { className = "withdrawn"; }
    contents = (
      <div>
        <div className="taxon">
          { taxonImageTag }
          <SplitTaxon
            taxon={ taxon }
            url={ `/taxa/${taxon.id}` }
            noInactive
          />
        </div>
        { item.body ? (
          <div
            className="id_body"
            dangerouslySetInnerHTML={ { __html: item.body } }
          />
        ) : null }
      </div>
    );
  } else {
    header = "commented";
    contents = (
      <div dangerouslySetInnerHTML={ { __html: item.body } } />
    );
  }
  const relativeTime = moment.parseZone( item.created_at ).fromNow( );
  return (
    <div className={ className }>
      <div className="icon">
        <UserImage user={ item.user } />
      </div>
      <Panel header={(
        <span>
          <span className="title_text">
            { userLink }&nbsp;
            { header }
          </span>
          <ActivityItemMenu
            item={ item }
            config={ config }
            deleteComment={ deleteComment }
            deleteID={ deleteID }
            restoreID={ restoreID }
          />
          <span className="time">
            { relativeTime }
          </span>
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
  deleteComment: PropTypes.func,
  deleteID: PropTypes.func,
  restoreID: PropTypes.func
};

export default ActivityItem;
