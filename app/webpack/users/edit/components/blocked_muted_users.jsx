import React from "react";
import PropTypes from "prop-types";

import SettingsItem from "./settings_item";
import UserFollowing from "./user_following";

const BlockedMutedUsers = ( {
  users,
  headerText,
  id,
  placeholder,
  buttonText,
  htmlDescription,
  searchUsers
} ) => (
  <div className="col-md-6">
    <SettingsItem header={headerText} htmlFor={id}>
      <div className="input-group">
        <input
          id={id}
          type="text"
          className="form-control"
          name={id}
          placeholder={placeholder}
          onChange={e => searchUsers( e )}
        />
      </div>
      {users.map( user => (
        <div className="row flex-no-wrap profile-photo-margin" key={user.name}>
          <div className="col-sm-9">
            <UserFollowing user={user} />
          </div>
          <div className="col-sm-3">
            <button type="button" className="btn btn-default btn-xs">
              {buttonText}
            </button>
          </div>
        </div>
      ) )}
    </SettingsItem>
    <p
      className="text-muted"
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={htmlDescription}
    />
  </div>
);

BlockedMutedUsers.propTypes = {
  users: PropTypes.array,
  headerText: PropTypes.string,
  id: PropTypes.string,
  placeholder: PropTypes.string,
  buttonText: PropTypes.string,
  htmlDescription: PropTypes.object,
  searchUsers: PropTypes.func
};

export default BlockedMutedUsers;
