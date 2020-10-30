import React from "react";
// import PropTypes from "prop-types";
import Pagination from "rc-pagination";

import SettingsItem from "./settings_item";
import CheckboxRowContainer from "../containers/checkbox_row_container";
import UserFollowing from "./user_following";

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

const Relationships = ( ) => (
  <div className="col-xs-9">
    <div className="row row-margin">
      <div className="col-xs-12">
        <SettingsItem header={I18n.t( "relationships_user_settings" )} htmlFor="relationships" />
        <div className="col-xs-3">
          <div className="row flex-no-wrap">
            <label className="margin-right" htmlFor="search_users">{I18n.t( "search" )}</label>
            <div className="input-group">
              <input
                id="search_users"
                type="text"
                className="form-control"
                name="search_users"
                placeholder={I18n.t( "username" )}
              />
            </div>
          </div>
        </div>
        <div className="col-xs-2 inat-affiliation-network-margin">
          <div className="row flex-no-wrap">
            <label className="margin-right" htmlFor="following">{I18n.t( "following" )}</label>
            <select
              className="form-control"
              id="following"
              name="following"
            >
              <option value="following">{I18n.t( "all" )}</option>
              <option value="following">{I18n.t( "yes" )}</option>
              <option value="following">{I18n.t( "no" )}</option>
            </select>
          </div>
        </div>
        <div className="col-xs-2 inat-affiliation-network-margin">
          <div className="row flex-no-wrap">
            <label className="margin-right" htmlFor="trusted">{I18n.t( "trusted" )}</label>
            <select
              className="form-control"
              id="trusted"
              name="trusted"
            >
              <option value="trusted">{I18n.t( "all" )}</option>
              <option value="trusted">{I18n.t( "yes" )}</option>
              <option value="trusted">{I18n.t( "no" )}</option>
            </select>
          </div>
        </div>
        <div className="col-xs-3 inat-affiliation-network-margin">
          <div className="row flex-no-wrap">
            <label className="margin-right" htmlFor="sort_by">{I18n.t( "sort_by" )}</label>
            <select
              className="form-control"
              id="sort_by"
              name="sort_by"
            >
              <option value="sort_by">{I18n.t( "recently_added" )}</option>
            </select>
          </div>
        </div>
      </div>
    </div>
    <div className="row">
      <div className="col-xs-3">
        <label>{I18n.t( "name" )}</label>
      </div>
      <div className="col-xs-4">
        <label>{I18n.t( "actions" )}</label>
      </div>
    </div>
    {sampleData.map( user => (
      <div className="row relationship-row-margin" key={user.name}>
        <div className="divider relationship-row-margin" />
        <div className="col-xs-4">
          <UserFollowing user={user} />
        </div>
        <div className="col-xs-4">
          <CheckboxRowContainer
            name="following"
            label={I18n.t( "following" )}
          />
          <CheckboxRowContainer
            name="trust"
            label={I18n.t( "trust_with_private_coordinates" )}
          />
          <dfn>{I18n.t( "user_trusts_you_with_their_private_coordinates", { user: user.username } )}</dfn>
        </div>
        <div className="col-xs-5 col-sm-4 centered-column">
          <dfn className="relationship-row-margin">{`${I18n.t( "added" )} ${user.date_added}`}</dfn>
          <button type="button" className="btn btn-default btn-xs">{I18n.t( "remove_relationship" )}</button>
        </div>
      </div>
    ) )}
    <div className="divider" />
    <div className="Pagination text-center">
      <Pagination
        total={200}
        current={1}
        pageSize={10}
        locale={{
          prev_page: I18n.t( "prev" ),
          next_page: I18n.t( "next" )
        }}
        onChange={( ) => console.log( "paginating" )}
        // onChange={page => loadPage( page )}
      />
    </div>
    <div className="row">
      <div className="col-xs-6">
        <SettingsItem header={I18n.t( "blocked_users" )} htmlFor="blocked_users">
          <div className="input-group">
            <input
              id="blocked_users"
              type="text"
              className="form-control"
              name="blocked_users"
              placeholder={I18n.t( "add_blocked_users" )}
            />
          </div>
          {sampleData.map( user => (
            <div className="row flex-no-wrap" key={user.name}>
              <div className="col-xs-9">
                <UserFollowing user={user} />
              </div>
              <div className="col-xs-3">
                <button type="button" className="btn btn-default btn-xs">{I18n.t( "unblock" )}</button>
              </div>
            </div>
          ) )}
        </SettingsItem>
        <p
          className="text-muted"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.users.edit.blocking_desc_html", {
              site_name: SITE.name,
              // noting that this help_email isn't populating
              help_email: SITE.help_email
            } )
          }}
        />
      </div>
      <div className="col-xs-6">
        <SettingsItem header={I18n.t( "muted_users" )} htmlFor="muted_users">
          <div className="input-group">
            <input
              id="muted_users"
              type="text"
              className="form-control"
              name="muted_users"
              placeholder={I18n.t( "add_muted_users" )}
            />
          </div>
          {sampleData.map( user => (
            <div className="row flex-no-wrap" key={user.name}>
              <div className="col-xs-9">
                <UserFollowing user={user} />
              </div>
              <div className="col-xs-3">
                <button type="button" className="btn btn-default btn-xs">{I18n.t( "unmute" )}</button>
              </div>
            </div>
          ) )}
        </SettingsItem>
        <p
          className="text-muted"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.users.edit.muting_desc_html" )
          }}
        />
      </div>
    </div>
  </div>
);

// Relationships.propTypes = {
//   showModal: PropTypes.func
// };

export default Relationships;
