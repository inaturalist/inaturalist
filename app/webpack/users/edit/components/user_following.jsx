import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";

const UserFollowing = ( { user } ) => (
  <div className="UserFollowing flex-no-wrap">
    <UserImage user={user} />
    <div className="names">
      <a href={`/people/${user.login}`}>{user.login}</a>
      <div>{user.name}</div>
    </div>
  </div>
);

UserFollowing.propTypes = {
  user: PropTypes.object
};

export default UserFollowing;
