import React from "react";
import PropTypes from "prop-types";

import SettingsItem from "./settings_item";
import UserFollowing from "./user_following";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";

const BlockedMutedUsers = ( {
  users,
  headerText,
  id,
  placeholder,
  buttonText,
  htmlDescription,
  blockOrMute,
  unblockOrUnmute
} ) => (
  <div className="col-md-6">
    <SettingsItem header={headerText} htmlFor={id}>
      <div className={`input-group ${users.length === 3 && id === "blocked_users" && "hidden"}`}>
        <UserAutocomplete
          resetOnChange={false}
          afterSelect={( { item } ) => blockOrMute( item, id )}
          bootstrapClear
          placeholder={placeholder}
        />
      </div>
      {users.map( user => (
        <div className="flex-no-wrap profile-photo-margin" key={user.friendUser.id}>
          <div className="col-sm-9">
            <UserFollowing user={user.friendUser} />
          </div>
          <div className="col-sm-3">
            <button
              type="button"
              className="btn btn-default btn-xs"
              onClick={( ) => unblockOrUnmute( user.friendUser.id, id )}
            >
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
  blockOrMute: PropTypes.func,
  unblockOrUnmute: PropTypes.func
};

export default BlockedMutedUsers;
