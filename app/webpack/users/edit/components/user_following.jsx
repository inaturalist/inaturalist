import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";

const UserFollowing = ( { user } ) => (
  <div className="row flex-no-wrap relationship-image">
    <UserImage user={user} />
    <div className="centered-column">
      <a href={`/people/${user.login}`}>{user.login}</a>
      <div>{user.name}</div>
    </div>
  </div>
);

UserFollowing.propTypes = {
  user: PropTypes.object
};

export default UserFollowing;
