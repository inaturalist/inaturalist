import React, { PropTypes } from "react";
import DiscussionListItemContainer from "../containers/discussion_list_item_container";

const DiscussionList = ( { observation } ) => {
  let items = ( observation.comments || [] ).map( ( c ) =>
    Object.assign( c, { className: "Comment", key: `Comment-${c.id}` } ) );
  const taxonIds = new Set( );
  items = items.concat( ( observation.identifications || [] ).map( ( i ) => {
    const hideAgree = taxonIds.has( i.taxon.id );
    taxonIds.add( i.taxon.id );
    return Object.assign( i, {
      className: "Identification",
      hideAgree
    } );
  } ) );
  items = items.sort( ( a, b ) => {
    if ( a.created_at < b.created_at ) {
      return -1;
    } else if ( a.created_at > b.created_at ) {
      return 1;
    }
    return 0;
  } );
  return (
    <div className="DiscussionList">
      {items.map( ( item ) => (
        <DiscussionListItemContainer
          className="stacked"
          key={`${item.className}-${item.id}`}
          user={item.user}
          body={item.body}
          createdAt={item.created_at}
          identification={item.className === "Identification" ? item : null}
          hideAgree={item.hideAgree ? true : null}
        />
      ) ) }
    </div>
  );
};

DiscussionList.propTypes = {
  observation: PropTypes.object.isRequired
};

export default DiscussionList;
