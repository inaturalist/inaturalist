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
  searchUsers
} ) => {
  const showRelationships = ( ) => relationships.map( user => {
    const { friendUser } = user;

    return (
      <div className="row relationship-row-margin" key={friendUser.login}>
        <div className="divider relationship-row-margin" />
        <div className="col-xs-4">
          <UserFollowing user={friendUser} />
        </div>
        <div className="col-sm-8">
          <div className="row">
            <div className="col-md-6">
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
              {user.reciprocal_trust && <em>{I18n.t( "user_trusts_you_with_their_private_coordinates", { user: friendUser.login } )}</em>}
            </div>
            <div className="col-md-6">
              <em className="relationship-row-margin">
                {I18n.t( "added_on_datetime", { datetime: moment( user.created_at ).format( "LL" ) } ) }
              </em>
              <div>
                <button
                  type="button"
                  className="btn btn-default btn-xs"
                  onClick={( ) => showModal( user.id, friendUser.login )}
                >
                  {I18n.t( "remove_relationship" )}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
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
      <div className="col-md-3">
        <div className="row flex-no-wrap search-margin">
          <label className="margin-right" htmlFor="name">{I18n.t( "search" )}</label>
          <div className="input-group margin-right-medium">
            <UserAutocomplete
              resetOnChange={false}
              afterSelect={( { item } ) => searchUsers( item )}
              afterUnselect={( ) => searchUsers( { item: { id: null } } )}
              bootstrapClear
              placeholder={I18n.t( "username" )}
            />
          </div>
        </div>
      </div>
      <div className="col-md-2 col-sm-3 col-xs-4 margin-right-medium">
        <div className="row flex-no-wrap">
          <label className="margin-right" htmlFor="following">{I18n.t( "following" )}</label>
          {renderDropdown( "following" )}
        </div>
      </div>
      <div className="col-md-2 col-sm-3 col-xs-4 margin-right-medium">
        <div className="row flex-no-wrap search-margin">
          <label className="margin-right" htmlFor="trusted">{I18n.t( "trusted" )}</label>
          {renderDropdown( "trusted" )}
        </div>
      </div>
      <div className="col-md-3 col-sm-4 col-xs-4">
        <div className="row flex-no-wrap">
          <label className="margin-right" htmlFor="sort_by">{I18n.t( "sort_by" )}</label>
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
      <p>
        <strong>
          {I18n.t( "youre_not_following_anyone_on_inat", { site_name: SITE.name } )}
        </strong>
      </p>
    </SettingsItem>
  );

  return (
    <div>
      <SettingsItem>
        <h4>{I18n.t( "relationships_user_settings" )}</h4>
        {showFilters( )}
      </SettingsItem>
      {relationships.length === 0 && showEmptyState( )}
      <div className={relationships.length === 0 ? "hidden" : null}>
        <div className="row hidden-xs">
          <div className="col-xs-4">
            <label>{I18n.t( "name" )}</label>
          </div>
          <div className="col-sm-8">
            <label>{I18n.t( "actions" )}</label>
          </div>
        </div>
        {relationships.length > 0 && showRelationships( )}
        <div className="divider" />
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
              // noting that this help_email isn't populating
              help_email: "help@inaturalist.org" // SITE.help_email
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
  searchUsers: PropTypes.func
};

export default Relationships;
