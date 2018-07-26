import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown, MenuItem } from "react-bootstrap";

const ActivityItemMenu = ( { item, config, deleteComment, deleteID, restoreID,
  setFlaggingModalState, linkTarget } ) => {
  if ( !item ) { return ( <div /> ); }
  const isID = !!item.taxon;
  let menuItems = [];
  const loggedInUser = ( config && config.currentUser ) ? config.currentUser : null;
  const viewerIsActor = loggedInUser && loggedInUser.id === item.user.id;
  const viewerIsCurator = loggedInUser && loggedInUser.roles && (
    loggedInUser.roles.indexOf( "admin" ) >= 0 || loggedInUser.roles.indexOf( "curator" ) >= 0
  );
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
    } else if ( loggedInUser ) {
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
            <i className="fa fa-arrow-circle-o-right" />
            <span className="menu-item-label">{ I18n.t( "you_" ) }</span>
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
            <i className="fa fa-arrow-circle-o-right" />
            <span className="menu-item-label">{ item.user.login }</span>
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
          <i className="fa fa-arrow-circle-o-right" />
          <span className="menu-item-label">{ I18n.t( "everyone_" ) }</span>
        </a>
      </div>
    ) );
    if ( !_.isEmpty( menuItems ) ) {
      menuItems.push( ( <MenuItem divider key={ `id-menu-divider-${item.id}` } /> ) );
    }
    menuItems.push(
      <li key={ `id-menu-links-${item.id}` } className="search-links">
        <div className="text-muted">
          { I18n.t( "view_observations_of_this_taxon_by" ) }:
        </div>
        { searchLinks }
      </li>
    );
    if ( loggedInUser ) {
      menuItems.push( ( <MenuItem divider key={ `id-identify-menu-divider-${item.id}` } /> ) );
      menuItems.push(
        <li key={ `id-identify-menu-links-${item.id}` } className="search-links">
          <div className="text-muted">
            { I18n.t( "identify_observations" ) }:
          </div>
          <div className="search">
            <a
              href={ `/observations/identify?taxon_id=${item.taxon.id}` }
              target={linkTarget}
            >
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ _.capitalize( I18n.t( "of_this_taxon" ) ) }</span>
            </a>
          </div>
          <div className="search">
            <a
              href={ `/observations/identify?user_id=${item.user.login}` }
              target={linkTarget}
            >
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ _.capitalize( I18n.t( "by_user", { user: item.user.login } ) ) }</span>
            </a>
          </div>
        </li>
      );
    }
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
    } else if ( loggedInUser ) {
      menuItems.push( (
        <MenuItem
          key={ `comment-flag-${item.id}` }
          eventKey="flag"
        >
          { I18n.t( "flag" ) }
        </MenuItem>
      ) );
      if ( viewerIsCurator ) {
        menuItems.push( (
          <MenuItem
            key={ `comment-delete-${item.id}` }
            eventKey="delete"
          >
            { I18n.t( "delete" ) }
          </MenuItem>
        ) );
      }
    }
  }
  return (
    <div className="ActivityItemMenu">
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={ key => {
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
          <Dropdown.Toggle noCaret disabled={ !!item.api_status || _.isEmpty( menuItems ) }>
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
