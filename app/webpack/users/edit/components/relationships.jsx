import React from "react";
import PropTypes from "prop-types";
import Pagination from "rc-pagination";
import moment from "moment";

import SettingsItem from "./settings_item";
import RelationshipsCheckboxContainer from "../containers/relationships_checkbox_container";
import UserFollowing from "./user_following";
import BlockedMutedUsersContainer from "../containers/blocked_muted_users_container";

const sampleData = [{
  name: "Carrie Seltzer",
  username: "carrieseltzer",
  userId: 1, // for link
  following: false,
  trust_with_hidden_coords: false,
  trusts_you_with_hidden_coords: true,
  blocked: false,
  muted: false,
  icon: "",
  date_added: "Jan 02, 2020"
}, {
  name: "Carrie Seltzer 2",
  username: "carrieseltzer2",
  userId: 1, // for link
  following: false,
  trust_with_hidden_coords: false,
  trusts_you_with_hidden_coords: false,
  blocked: false,
  muted: false,
  icon: "",
  date_added: "Jan 02, 2020"
}];

const Relationships = ( {
  relationships,
  profile,
  filteredRelationships,
  updateFilters,
  sortRelationships,
  showModal
} ) => {
  const showRelationships = ( ) => filteredRelationships.map( user => {
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
                friendId={friendUser.id}
              />
              <RelationshipsCheckboxContainer
                name="trust"
                label={I18n.t( "trust_with_private_coordinates" )}
                friendId={friendUser.id}
              />
              {user.reciprocal_trust && <dfn>{I18n.t( "user_trusts_you_with_their_private_coordinates", { user: friendUser.login } )}</dfn>}
            </div>
            <div className="col-md-6">
              <dfn className="relationship-row-margin">
                {`${I18n.t( "added" )} ${moment( friendUser.created_at ).format( "LL" )}`}
              </dfn>
              <div>
                <button
                  type="button"
                  className="btn btn-default btn-xs"
                  onClick={( ) => showModal( friendUser.id, friendUser.login )}
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

  return (
    <div>
      <SettingsItem>
        <h4>{I18n.t( "relationships_user_settings" )}</h4>
        <div className="col-md-3">
          <div className="row flex-no-wrap search-margin">
            <label className="margin-right" htmlFor="name">{I18n.t( "search" )}</label>
            <div className="input-group margin-right-medium">
              <input
                id="name"
                type="text"
                className="form-control"
                name="name"
                placeholder={I18n.t( "username" )}
                onChange={updateFilters}
              />
            </div>
          </div>
        </div>
        <div className="col-md-2 col-sm-3 col-xs-4 margin-right-medium">
          <div className="row flex-no-wrap">
            <label className="margin-right" htmlFor="following">{I18n.t( "following" )}</label>
            <select
              className="form-control"
              id="following"
              name="following"
              onChange={updateFilters}
            >
              <option value="all">{I18n.t( "all" )}</option>
              <option value="yes">{I18n.t( "yes" )}</option>
              <option value="no">{I18n.t( "no" )}</option>
            </select>
          </div>
        </div>
        <div className="col-md-2 col-sm-3 col-xs-4 margin-right-medium">
          <div className="row flex-no-wrap search-margin">
            <label className="margin-right" htmlFor="trusted">{I18n.t( "trusted" )}</label>
            <select
              className="form-control"
              id="trusted"
              name="trusted"
              onChange={updateFilters}
            >
              <option value="all">{I18n.t( "all" )}</option>
              <option value="yes">{I18n.t( "yes" )}</option>
              <option value="no">{I18n.t( "no" )}</option>
            </select>
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
      </SettingsItem>
      <div className="row hidden-xs">
        <div className="col-xs-4">
          <label>{I18n.t( "name" )}</label>
        </div>
        <div className="col-sm-8">
          <label>{I18n.t( "actions" )}</label>
        </div>
      </div>
      {filteredRelationships.length > 0 && showRelationships( )}
      <div className="divider" />
      <div className="Pagination text-center">
        <Pagination
          total={filteredRelationships.length}
          current={1}
          pageSize={10}
          onChange={( ) => console.log( "paginating" )}
          // onChange={page => loadPage( page )}
        />
      </div>
      <div className="row">
        <BlockedMutedUsersContainer
          users={sampleData}
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
        {profile.muted_user_ids && (
          <BlockedMutedUsersContainer
            users={relationships.filter( u => profile.muted_user_ids.includes( u.friendUser.id ) )}
            headerText={I18n.t( "muted_users" )}
            id="muted_users"
            placeholder={I18n.t( "add_muted_users" )}
            buttonText={I18n.t( "unmute" )}
            htmlDescription={{
              __html: I18n.t( "views.users.edit.muting_desc_html" )
            }}
          />
        )}
      </div>
    </div>
  );
};

Relationships.propTypes = {
  relationships: PropTypes.array,
  profile: PropTypes.object,
  filteredRelationships: PropTypes.array,
  updateFilters: PropTypes.func,
  sortRelationships: PropTypes.func,
  showModal: PropTypes.func
};

export default Relationships;
