import React from "react";
import PropTypes from "prop-types";

import SettingsItem from "./settings_item";
import UserFollowing from "./user_following";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";

const BlockedMutedUsers = ( {
  mutedUsers,
  headerText,
  id,
  placeholder,
  buttonText,
  htmlDescription,
  blockOrMute,
  unblockOrUnmute,
  blockedUsers
} ) => {
  const displayList = user => (
    <div className="row flex-no-wrap profile-photo-margin" key={user.id}>
      <div className="col-sm-6">
        <UserFollowing user={user} />
      </div>
      <div className="col-sm-6">
        <button
          type="button"
          className="btn btn-default"
          onClick={( ) => unblockOrUnmute( user.id, id )}
        >
          {buttonText}
        </button>
      </div>
    </div>
  );

  return (
    <div className="col-md-6">
      <SettingsItem header={headerText} htmlFor={id}>
        <div className={`input-group ${blockedUsers.length === 3 && id === "blocked_users" && "hidden"}`}>
          <UserAutocomplete
            resetOnChange={false}
            afterSelect={( { item } ) => blockOrMute( item, id )}
            bootstrapClear
            placeholder={placeholder}
          />
        </div>
        {id === "muted_users"
          ? mutedUsers.map( user => displayList( user ) )
          : blockedUsers.map( user => displayList( user ) )}
      </SettingsItem>
      <p
        className="text-muted"
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={htmlDescription}
      />
    </div>
  );
};

BlockedMutedUsers.propTypes = {
  mutedUsers: PropTypes.array,
  headerText: PropTypes.string,
  id: PropTypes.string,
  placeholder: PropTypes.string,
  buttonText: PropTypes.string,
  htmlDescription: PropTypes.object,
  blockOrMute: PropTypes.func,
  unblockOrUnmute: PropTypes.func,
  blockedUsers: PropTypes.array
};

export default BlockedMutedUsers;
