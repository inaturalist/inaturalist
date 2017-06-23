import React, { PropTypes } from "react";
import { Dropdown, MenuItem } from "react-bootstrap";


const ActivityItemMenu = ( { item, config, deleteComment, deleteID, restoreID,
  setFlaggingModalState, linkTarget} ) => {
  if ( !item ) { return ( <div /> ); }
  const isID = !!item.taxon;
  let menuItems = [];
  const loggedInUser = ( config && config.currentUser ) ? config.currentUser : null;
  const viewerIsActor = loggedInUser && loggedInUser.id === item.user.id;
  if ( isID ) {
    if ( viewerIsActor ) {
      menuItems.push( (
        <MenuItem
          key={ `id-edit-${item.id}` }
          eventKey="edit"
          href={ `/identifications/${item.id}/edit` }
          target={linkTarget}
        >
          { I18n.t( "edit" ) }
        </MenuItem>
      ) );
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
    const searchLinks = [];
    if ( loggedInUser ) {
      searchLinks.push( (
        <div className="search" key={ `id-search-you-${item.id}` }>
          <a
            href={ `/observations?taxon_id=${item.taxon.id}&user_id=${loggedInUser.id}` }
            target={linkTarget}
          >
            <i className="fa fa-arrow-circle-o-right" />{ I18n.t( "you_" ) }
          </a>
        </div>
      ) );
    }
    if ( !( loggedInUser && loggedInUser.id === item.user.id ) ) {
      searchLinks.push( (
        <div className="search" key={ `id-search-user-${item.id}` }>
          <a
            href={ `/observations?taxon_id=${item.taxon.id}&user_id=${item.user.id}` }
            target={linkTarget}
          >
            <i className="fa fa-arrow-circle-o-right" />{ item.user.login }
          </a>
        </div>
      ) );
    }
    searchLinks.push( (
      <div className="search" key={ `id-search-all-${item.id}` }>
        <a
          href={ `/observations?taxon_id=${item.taxon.id}` }
          target={linkTarget}
        >
          <i className="fa fa-arrow-circle-o-right" />{ I18n.t( "everyone_" ) }
        </a>
      </div>
    ) );
    menuItems.push( ( <MenuItem divider key={ `id-menu-divider-${item.id}` } /> ) );
    menuItems.push( ( <div key={ `id-menu-links-${item.id}` } className="search-links">
      <div className="text-muted">
        { I18n.t( "view_observations_of_this_taxon_by" ) }:
      </div> { searchLinks }
    </div> ) );
  } else {
    if ( viewerIsActor ) {
      menuItems.push( (
        <MenuItem
          key={ `comment-edit-${item.id}` }
          eventKey="edit"
          href={ `/comments/${item.id}/edit` }
          target={linkTarget}
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
  setFlaggingModalState: PropTypes.func,
  linkTarget: PropTypes.string
};

export default ActivityItemMenu;
