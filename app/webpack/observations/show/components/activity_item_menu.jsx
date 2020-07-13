import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown, MenuItem } from "react-bootstrap";

const ActivityItemMenu = ( {
  item,
  config,
  deleteComment,
  deleteID,
  editing,
  restoreID,
  setFlaggingModalState,
  linkTarget,
  observation,
  onEdit,
  trustUser,
  untrustUser,
  hideContent,
  unhideContent
} ) => {
  if ( !item ) { return ( <div /> ); }
  const isID = !!item.taxon;
  const menuItems = [];
  const loggedInUser = ( config && config.currentUser ) ? config.currentUser : null;
  const viewerIsActor = loggedInUser && loggedInUser.id === item.user.id;
  const viewerIsCurator = loggedInUser && loggedInUser.roles && (
    loggedInUser.roles.indexOf( "admin" ) >= 0 || loggedInUser.roles.indexOf( "curator" ) >= 0
  );
  const viewerIsAdmin = loggedInUser && loggedInUser.roles
    && loggedInUser.roles.indexOf( "admin" ) >= 0;
  if ( isID ) {
    if ( viewerIsActor ) {
      if ( !item.hidden ) {
        menuItems.push( (
          <MenuItem
            key={`id-edit-${item.id}`}
            eventKey="edit"
            href={`/identifications/${item.id}/edit`}
            onClick={onEdit}
            target={linkTarget}
          >
            { editing ? I18n.t( "stop_editing" ) : I18n.t( "edit" ) }
          </MenuItem>
        ) );
      }
      if ( item.current ) {
        menuItems.push( (
          <MenuItem
            key={`id-delete-${item.id}`}
            eventKey="delete"
          >
            { I18n.t( "withdraw" ) }
          </MenuItem>
        ) );
      } else {
        menuItems.push( (
          <MenuItem
            key={`id-restore-${item.id}`}
            eventKey="restore"
          >
            { I18n.t( "restore" ) }
          </MenuItem>
        ) );
      }
    } else if ( loggedInUser ) {
      menuItems.push( (
        <MenuItem
          key={`id-flag-${item.id}`}
          eventKey="flag"
        >
          { I18n.t( "flag" ) }
        </MenuItem>
      ) );
      if ( viewerIsCurator && !item.hidden && !_.isEmpty( item.body ) ) {
        menuItems.push( (
          <MenuItem
            key={`identification-hide-${item.id}`}
            eventKey="hide-identification"
          >
            { I18n.t( "hide_content" ) }
          </MenuItem>
        ) );
      }
      if ( viewerIsAdmin && item.hidden ) {
        menuItems.push( (
          <MenuItem
            key={`identification-unhide-${item.id}`}
            eventKey="unhide-identification"
          >
            { I18n.t( "unhide_content" ) }
          </MenuItem>
        ) );
      }
    }
    if ( item.flags && item.flags.length > 0 ) {
      menuItems.push( (
        <MenuItem
          key={`id-view-flags-${item.id}`}
          eventKey="view-flags-for-identification"
        >
          { I18n.t( "view_flags" ) }
          { " " }
          <span className="text-muted">{ `(${item.flags.length})` }</span>
        </MenuItem>
      ) );
    }
    const searchLinks = [];
    if ( loggedInUser ) {
      searchLinks.push( (
        <div className="search" key={`id-search-you-${item.id}`}>
          <a
            href={`/observations?taxon_id=${item.taxon.id}&user_id=${loggedInUser.id}`}
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
        <div className="search" key={`id-search-user-${item.id}`}>
          <a
            href={`/observations?taxon_id=${item.taxon.id}&user_id=${item.user.id}`}
            target={linkTarget}
          >
            <i className="fa fa-arrow-circle-o-right" />
            <span className="menu-item-label">{ item.user.login }</span>
          </a>
        </div>
      ) );
    }
    searchLinks.push( (
      <div className="search" key={`id-search-all-${item.id}`}>
        <a
          href={`/observations?taxon_id=${item.taxon.id}`}
          target={linkTarget}
        >
          <i className="fa fa-arrow-circle-o-right" />
          <span className="menu-item-label">{ I18n.t( "everyone_" ) }</span>
        </a>
      </div>
    ) );
    if ( !_.isEmpty( menuItems ) ) {
      menuItems.push( ( <MenuItem divider key={`id-menu-divider-${item.id}`} /> ) );
    }
    menuItems.push(
      <li key={`id-menu-links-${item.id}`} className="search-links">
        <div className="text-muted">
          { I18n.t( "label_colon", { label: I18n.t( "view_observations_of_this_taxon_by" ) } ) }
        </div>
        { searchLinks }
      </li>
    );
    if ( loggedInUser ) {
      menuItems.push( ( <MenuItem divider key={`id-identify-menu-divider-${item.id}`} /> ) );
      menuItems.push(
        <li key={`id-identify-menu-links-${item.id}`} className="search-links">
          <div className="text-muted">
            { I18n.t( "label_colon", { label: I18n.t( "identify_observations" ) } ) }
          </div>
          <div className="search">
            <a
              href={`/observations/identify?taxon_id=${item.taxon.id}`}
              target={linkTarget}
            >
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "of_this_taxon" ) }</span>
            </a>
          </div>
          <div className="search">
            <a
              href={`/observations/identify?user_id=${item.user.login}`}
              target={linkTarget}
            >
              <i className="fa fa-arrow-circle-o-right" />
              <span className="menu-item-label">{ I18n.t( "by_user", { user: item.user.login } ) }</span>
            </a>
          </div>
        </li>
      );
    }
  } else if ( viewerIsActor && !item.hidden ) {
    // Item is a comment and the viewer is the author of that comment
    menuItems.push( (
      <MenuItem
        key={`comment-edit-${item.id}`}
        eventKey="edit"
        href={`/comments/${item.id}/edit`}
        onClick={onEdit}
        target={linkTarget}
      >
        { editing ? I18n.t( "stop_editing" ) : I18n.t( "edit" ) }
      </MenuItem>
    ) );
    menuItems.push( (
      <MenuItem
        key={`comment-delete-${item.id}`}
        eventKey="delete"
      >
        { I18n.t( "delete" ) }
      </MenuItem>
    ) );
  } else if ( loggedInUser ) {
    // Item is a comment and viewer is logged in
    menuItems.push( (
      <MenuItem
        key={`comment-flag-${item.id}`}
        eventKey="flag"
      >
        { I18n.t( "flag" ) }
      </MenuItem>
    ) );
    if ( viewerIsCurator && !item.hidden ) {
      menuItems.push( (
        <MenuItem
          key={`comment-hide-${item.id}`}
          eventKey="hide-comment"
        >
          { I18n.t( "hide_content" ) }
        </MenuItem>
      ) );
    }
    if ( viewerIsAdmin && item.hidden ) {
      menuItems.push( (
        <MenuItem
          key={`comment-unhide-${item.id}`}
          eventKey="unhide-comment"
        >
          { I18n.t( "unhide_content" ) }
        </MenuItem>
      ) );
    }
  }
  if ( item.flags && item.flags.length > 0 ) {
    menuItems.push( (
      <MenuItem
        key={`comment-view-flags-${item.id}`}
        eventKey="view-flags-for-comment"
      >
        { I18n.t( "view_flags" ) }
        { " " }
        <span className="text-muted">{ `(${item.flags.length})` }</span>
      </MenuItem>
    ) );
  }
  if (
    trustUser
    && untrustUser
    && loggedInUser
    && !viewerIsActor
    && observation
    && observation.user.id === loggedInUser.id
  ) {
    menuItems.push( ( <MenuItem divider key={`trust-divider-${item.id}`} /> ) );
    loggedInUser.trusted_user_ids = loggedInUser.trusted_user_ids || [];
    if ( loggedInUser.trusted_user_ids.indexOf( item.user.id ) >= 0 ) {
      menuItems.push( (
        <MenuItem
          key={`remove-trust-${item.id}`}
          eventKey="remove-trust"
          className="search"
        >
          <i className="icon-person" />
          { I18n.t( "stop_trusting_this_person_with_your_private_coordinates" ) }
        </MenuItem>
      ) );
    } else {
      menuItems.push( (
        <MenuItem
          key={`add-trust-${item.id}`}
          eventKey="add-trust"
          className="search"
        >
          <i className="icon-person" />
          { I18n.t( "trust_this_person_with_your_private_coordinates" )}
        </MenuItem>
      ) );
    }
    menuItems.push( (
      <li key={`comment-delete-${item.id}`} className="search">
        <a href="/relationships" target="_blank">
          <i className="icon-people" />
          { I18n.t( "manage_your_relationships" ) }
        </a>
      </li>
    ) );
  }
  return (
    <div className="ActivityItemMenu">
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={key => {
            if ( key === "flag" ) {
              setFlaggingModalState( { item, show: true } );
            } else if ( key === "view-flags-for-comment" ) {
              window.open( `/comments/${item.id}/flags`, "_blank" );
            } else if ( key === "view-flags-for-identification" ) {
              window.open( `/identifications/${item.id}/flags`, "_blank" );
            } else if ( key === "add-trust" ) {
              trustUser( item.user );
            } else if ( key === "remove-trust" ) {
              untrustUser( item.user );
            } else if ( key === "manage-relationships" ) {
              window.open( "/relationships", "_blank" );
            } else if ( isID && key === "delete" ) {
              deleteID( item.id );
            } else if ( isID && key === "restore" ) {
              restoreID( item.id );
            } else if ( key === "delete" ) {
              deleteComment( item.id );
            } else if ( key === "hide-comment" || key === "hide-identification" ) {
              hideContent( item );
            } else if ( key === "unhide-comment" || key === "unhide-identification" ) {
              unhideContent( item );
            }
          }}
          disabled={!!item.api_status || _.isEmpty( menuItems )}
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
  observation: PropTypes.object,
  onEdit: PropTypes.func,
  config: PropTypes.object,
  deleteComment: PropTypes.func,
  deleteID: PropTypes.func,
  editing: PropTypes.bool,
  restoreID: PropTypes.func,
  setFlaggingModalState: PropTypes.func,
  linkTarget: PropTypes.string,
  trustUser: PropTypes.func,
  untrustUser: PropTypes.func,
  hideContent: PropTypes.func,
  unhideContent: PropTypes.func
};

export default ActivityItemMenu;
