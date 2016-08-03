import React, { PropTypes } from "react";
import DiscussionListItemContainer from "../containers/discussion_list_item_container";

const DiscussionList = ( { observation, onDelete, onRestore } ) => {
  let items = ( observation.comments || [] ).map( ( c ) => (
    Object.assign( c, {
      className: "Comment",
      key: `Comment-${c.id}`,
      editUrl: `/comments/${c.id}/edit`
    } )
  ) );
  const taxonIds = new Set( );
  items = items.concat( ( observation.identifications || [] ).map( ( i ) => {
    const hideAgree = taxonIds.has( i.taxon.id ) || !i.taxon.is_active;
    taxonIds.add( i.taxon.id );
    return Object.assign( i, {
      className: "Identification",
      hideAgree,
      editUrl: `/identifications/${i.id}/edit`
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
          onEdit={ ( ) => {
            window.open( item.editUrl, "_blank" );
          } }
          onDelete={ ( ) => {
            if ( confirm( I18n.t( "are_you_sure?" ) ) ) {
              onDelete( item );
            }
          } }
          onRestore={ ( ) => onRestore( item ) }
        />
      ) ) }
    </div>
  );
};

DiscussionList.propTypes = {
  observation: PropTypes.object.isRequired,
  onDelete: PropTypes.func,
  onRestore: PropTypes.func
};

export default DiscussionList;
