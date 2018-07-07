import React from "react";
import PropTypes from "prop-types";
import moment from "moment";
import _ from "lodash";
import ActivityItemContainer from "../containers/activity_item_container";

const DiscussionList = ( { observation, currentUserID } ) => {
  let items = ( observation.comments || [] ).map( ( c ) => (
    Object.assign( c, {
      className: "Comment",
      key: `Comment-${c.id}`,
      editUrl: `/comments/${c.id}/edit`
    } )
  ) );
  const taxonIds = new Set( );
  const idents = ( observation.identifications || [] );
  const currentUserIdent = _.find( idents, i => currentUserID && i.user.id === currentUserID );
  if ( currentUserIdent ) {
    taxonIds.add( currentUserIdent.taxon.id );
  }
  items = items.concat( idents.map( ( i ) => {
    const hideAgree = taxonIds.has( i.taxon.id ) || !i.taxon.is_active;
    taxonIds.add( i.taxon.id );
    return Object.assign( i, {
      className: "Identification",
      hideAgree,
      editUrl: `/identifications/${i.id}/edit`
    } );
  } ) );
  items = items.sort( ( a, b ) => {
    const dateA = moment( a.created_at );
    const dateB = moment( b.created_at );
    if ( dateA < dateB ) {
      return -1;
    } else if ( dateA > dateB ) {
      return 1;
    }
    return 0;
  } );
  const taxonIDsDisplayed = {};
  return (
    <div className="DiscussionList">
      {items.map( ( item ) => {
        let firstDisplay;
        let key = `activity-item-comment-${item.id}`;
        if ( item.taxon && item.current ) {
          firstDisplay = !taxonIDsDisplayed[item.taxon.id];
          taxonIDsDisplayed[item.taxon.id] = true;
          key = `activity-item-identification-${item.id}`;
        }
        return (
          <ActivityItemContainer
            key={ key }
            item={ item }
            observation={ observation }
            firstDisplay={ firstDisplay }
            linkTarget="_blank"
          />
        );
      } ) }
    </div>
  );
};

DiscussionList.propTypes = {
  observation: PropTypes.object.isRequired,
  onDelete: PropTypes.func,
  onRestore: PropTypes.func,
  currentUserID: PropTypes.number
};

export default DiscussionList;
