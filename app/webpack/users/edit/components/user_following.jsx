import React from "react";
import PropTypes from "prop-types";

const UserFollowing = ( { user } ) => (
  <div className="row flex-no-wrap profile-photo-margin">
    <img
      alt="user-following"
      src={user.icon_url}
      className="user-photo margin-right-medium"
    />
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
