import React, { PropTypes } from "react";
import { Dropdown, MenuItem } from "react-bootstrap";


const ActivityItemMenu = ( { item, config, deleteComment, deleteID, restoreID,
  setFlaggingModalState } ) => {
  if ( !item ) { return ( <div /> ); }
  const isID = !!item.taxon;
  let menuItems = [];
  const viewerIsActor = config && config.currentUser && config.currentUser.id === item.user.id;
  if ( isID ) {
    if ( viewerIsActor ) {
      if ( item.current ) {
        menuItems.push( (
          <MenuItem
            key={ `id-delete-${item.id}` }
            eventKey="delete"
          >
            { I18n.t( "withdraw" ) }
          </MenuItem>
        ) );
      } else {
        menuItems.push( (
          <MenuItem
            key={ `id-restore-${item.id}` }
            eventKey="restore"
          >
            { I18n.t( "restore" ) }
          </MenuItem>
        ) );
      }
    } else {
      menuItems.push( (
        <MenuItem
          key={ `id-flag-${item.id}` }
          eventKey="flag"
        >
          { I18n.t( "flag" ) }
        </MenuItem>
      ) );
    }
  } else {
    if ( viewerIsActor ) {
      menuItems.push( (
        <MenuItem
          key={ `comment-edit-${item.id}` }
          eventKey="edit"
          href={ `/comments/${item.id}/edit` }
        >
          { I18n.t( "edit" ) }
        </MenuItem>
      ) );
      menuItems.push( (
        <MenuItem
          key={ `comment-delete-${item.id}` }
          eventKey="delete"
        >
          { I18n.t( "delete" ) }
        </MenuItem>
      ) );
    } else {
      menuItems.push( (
        <MenuItem
          key={ `comment-flag-${item.id}` }
          eventKey="flag"
        >
          { I18n.t( "flag" ) }
        </MenuItem>
      ) );
    }
  }
  return (
    <div className="ActivityItemMenu">
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={ ( event, key ) => {
            if ( key === "flag" ) {
              setFlaggingModalState( { item, show: true } );
            } else if ( isID ) {
              if ( key === "delete" ) {
                deleteID( item.id );
              } else if ( key === "restore" ) {
                restoreID( item.id );
              }
            } else {
              if ( key === "delete" ) {
                deleteComment( item.id );
              }
            }
          } }
        >
          <Dropdown.Toggle noCaret disabled={ !!item.api_status }>
            <i className="fa fa-chevron-down" />
          </Dropdown.Toggle>
          <Dropdown.Menu className="dropdown-menu-right">
            { menuItems }
          </Dropdown.Menu>
        </Dropdown>
      </span>
    </div>
  );
};

ActivityItemMenu.propTypes = {
  item: PropTypes.object,
  config: PropTypes.object,
  deleteComment: PropTypes.func,
  deleteID: PropTypes.func,
  restoreID: PropTypes.func,
  setFlaggingModalState: PropTypes.func
};

export default ActivityItemMenu;
