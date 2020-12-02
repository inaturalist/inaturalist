import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";

const UserFollowing = ( { user } ) => (
  <div className="flex-no-wrap relationship-profile-image">
    <UserImage user={user} />
    <div>
      <a href={`/people/${user.login}`}>{user.login}</a>
      <div>{user.name}</div>
    </div>
  </div>
);

UserFollowing.propTypes = {
  user: PropTypes.object
};

export default UserFollowing;
