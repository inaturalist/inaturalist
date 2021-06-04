import React from "react";
import PropTypes from "prop-types";
import Pagination from "rc-pagination";
import moment from "moment";

import SettingsItem from "./settings_item";
import RelationshipsCheckboxContainer from "../containers/relationships_checkbox_container";
import UserFollowing from "./user_following";
import BlockedMutedUsersContainer from "../containers/blocked_muted_users_container";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";

const Relationships = ( {
  relationships,
  filterRelationships,
  sortRelationships,
  showModal,
  loadPage,
  page,
  totalRelationships,
  searchUsers,
  filters
} ) => {
  const createRelationshipRow = ( ) => relationships.map( user => {
    const { friendUser } = user;

    return (
      <tr key={friendUser.login}>
        <td className="col-xs-4">
          <UserFollowing user={friendUser} />
        </td>
        <td className="table-row col-xs-4">
          <RelationshipsCheckboxContainer
            name="following"
            label={I18n.t( "following" )}
            id={user.id}
            relationships={relationships}
          />
          <RelationshipsCheckboxContainer
            name="trust"
            label={I18n.t( "trust_with_private_coordinates" )}
            id={user.id}
            relationships={relationships}
          />
          <div className={`${!user.reciprocal_trust ? "hidden" : "reciprocal-trust"}`}>
            <em>
              {I18n.t( "user_trusts_you_with_their_private_coordinates", { user: friendUser.login } )}
            </em>
          </div>
        </td>
        <td className="table-row col-xs-4">
          <em className="stacked">
            {I18n.t( "added_on_datetime", { datetime: moment( user.created_at ).format( "LL" ) } ) }
          </em>
          <div>
            <button
              type="button"
              className="btn btn-default btn-remove-relationship"
              onClick={( ) => showModal( user.id, friendUser.login )}
            >
              {I18n.t( "remove_relationship" )}
            </button>
          </div>
        </td>
      </tr>
    );
  } );

  const renderDropdown = id => (
    <select
      className="form-control"
      id={id}
      name={id}
      onChange={filterRelationships}
    >
      <option value="all">{I18n.t( "all" )}</option>
      <option value="yes">{I18n.t( "yes" )}</option>
      <option value="no">{I18n.t( "no" )}</option>
    </select>
  );

  const showFilters = ( ) => (
    <div>
      <div id="relationships-filters">
        <div className="filter">
          <label className="relationship-label" htmlFor="name">{I18n.t( "search" )}</label>
          <div className="input-group">
            <UserAutocomplete
              resetOnChange
              afterSelect={( { item } ) => searchUsers( item )}
              afterUnselect={( ) => searchUsers( { item: { id: null } } )}
              bootstrapClear
              placeholder={I18n.t( "username" )}
            />
          </div>
        </div>
        <div className="filter">
          <label className="relationship-label" htmlFor="following">{I18n.t( "following" )}</label>
          {renderDropdown( "following" )}
        </div>
        <div className="filter">
          <label className="relationship-label" htmlFor="trusted">{I18n.t( "trusted" )}</label>
          {renderDropdown( "trusted" )}
        </div>
        <div className="filter">
          <label className="relationship-label" htmlFor="sort_by">{I18n.t( "sort_by" )}</label>
          <select
            className="form-control"
            id="sort_by"
            name="sort_by"
            onChange={sortRelationships}
          >
            <option value="recently_added">{I18n.t( "recently_added" )}</option>
            <option value="earliest_added">{I18n.t( "earliest_added" )}</option>
            <option value="a_to_z">{I18n.t( "a_to_z" )}</option>
            <option value="z_to_a">{I18n.t( "z_to_a" )}</option>
          </select>
        </div>
      </div>
    </div>
  );

  const showEmptyState = ( ) => (
    <SettingsItem>
      <p className="nocontent">
        {( filters.following !== "all" || filters.trusted !== "all" )
          ? I18n.t( "no_users_found_with_those_filters" )
          : I18n.t( "youre_not_following_anyone_on_inat", { site_name: SITE.name } )
        }
      </p>
    </SettingsItem>
  );

  return (
    <div>
      <h4>{I18n.t( "relationships_user_settings" )}</h4>
      {showFilters( )}
      {relationships.length === 0 && showEmptyState( )}
      <table className={`table divider ${relationships.length === 0 ? "hidden" : null}`}>
        <thead>
          <tr className="hidden-xs">
            <th>{I18n.t( "name" )}</th>
            <th>{I18n.t( "actions" )}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {relationships.length > 0 && createRelationshipRow( )}
        </tbody>
      </table>
      <div className={relationships.length === 0 ? "hidden" : null}>
        <div className="Pagination text-center">
          <Pagination
            total={totalRelationships}
            current={page}
            pageSize={10}
            onChange={p => loadPage( p )}
          />
        </div>
      </div>
      <div className="row">
        <BlockedMutedUsersContainer
          headerText={I18n.t( "blocked_users" )}
          id="blocked_users"
          placeholder={I18n.t( "add_blocked_users" )}
          buttonText={I18n.t( "unblock" )}
          htmlDescription={{
            __html: I18n.t( "views.users.edit.blocking_desc_html", {
              site_name: SITE.name,
              help_email: SITE.help_email
            } )
          }}
        />
        <BlockedMutedUsersContainer
          headerText={I18n.t( "muted_users" )}
          id="muted_users"
          placeholder={I18n.t( "add_muted_users" )}
          buttonText={I18n.t( "unmute" )}
          htmlDescription={{
            __html: I18n.t( "views.users.edit.muting_desc_html" )
          }}
        />
      </div>
    </div>
  );
};

Relationships.propTypes = {
  relationships: PropTypes.array,
  filterRelationships: PropTypes.func,
  sortRelationships: PropTypes.func,
  showModal: PropTypes.func,
  loadPage: PropTypes.func,
  page: PropTypes.number,
  totalRelationships: PropTypes.number,
  searchUsers: PropTypes.func,
  filters: PropTypes.object
};

export default Relationships;
