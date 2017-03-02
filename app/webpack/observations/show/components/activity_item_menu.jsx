import React, { PropTypes } from "react";
import { Dropdown, MenuItem } from "react-bootstrap";


const ActivityItemMenu = ( { item, config, deleteComment, deleteID,
                             restoreID, setFlaggingModalState } ) => {
  if ( !item ) { return ( <div /> ); }
  const isID = !!item.taxon;
  let menuItems = [];
  const viewerIsObserver = config && config.currentUser && config.currentUser.id === item.user.id;
  if ( isID && viewerIsObserver ) {
    if ( viewerIsObserver ) {
      if ( item.current ) {
        menuItems.push( (
          <MenuItem
            key={ `id-delete-${item.id}` }
            eventKey="delete"
          >
            Withdraw
          </MenuItem>
        ) );
      } else {
        menuItems.push( (
          <MenuItem
            key={ `id-restore-${item.id}` }
            eventKey="restore"
          >
            Restore
          </MenuItem>
        ) );
      }
    } else {
      menuItems.push( (
        <MenuItem
          key={ `id-flag-${item.id}` }
          eventKey="flag"
        >
          Flag
        </MenuItem>
      ) );
    }
  } else {
    if ( viewerIsObserver ) {
      menuItems.push( (
        <MenuItem
          key={ `comment-delete-${item.id}` }
          eventKey="delete"
        >
          Delete
        </MenuItem>
      ) );
    } else {
      menuItems.push( (
        <MenuItem
          key={ `comment-flag-${item.id}` }
          eventKey="flag"
        >
          Flag
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
              setFlaggingModalState( "item", item );
              setFlaggingModalState( "show", true );
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
          <Dropdown.Toggle noCaret>
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
