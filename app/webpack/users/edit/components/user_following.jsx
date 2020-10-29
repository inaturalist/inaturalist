import React from "react";
import PropTypes from "prop-types";

const UserFollowing = ( { user } ) => (
  <div className="row profile-photo-margin">
    <div className="col-xs-3">
      <img
        alt="user-following"
        src={user.icon}
        className="user-photo"
      />
    </div>
    <div className="col-xs-7 centered-column">
      <a href="#">{user.username}</a>
      <div>{user.name}</div>
    </div>
  </div>
);

UserFollowing.propTypes = {
  user: PropTypes.object
};

export default UserFollowing;
