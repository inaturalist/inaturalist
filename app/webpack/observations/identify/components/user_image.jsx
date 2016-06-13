import React, { PropTypes } from "react";

const UserImage = ( { user } ) => (
  <a
    className="userimage UserImage"
    href={`/people/${user.login || user.id}`}
    title={user.login}
    style={ {
      backgroundImage: user.icon_url ? `url( '${user.icon_url}' )` : ""
    } }
    target="_self"
  >
    <i
      className="icon-person"
      style={ {
        display: user.icon_url ? "none" : "inline"
      } }
    />
  </a>
);

UserImage.propTypes = {
  user: PropTypes.object
};

export default UserImage;
