import React, { PropTypes } from "react";

const UserImage = ( { user, linkTarget } ) => {
  const icon = (
    <i
      className="icon-person"
      style={ {
        display: user && user.icon_url ? "none" : "inline"
      } }
    />
  );
  const style = {
    backgroundImage: user && user.icon_url ? `url( '${user.icon_url}' )` : ""
  };
  if ( user ) {
    return (
      <a
        className="userimage UserImage"
        href={`/people/${user.login || user.id}`}
        title={user.login}
        style={ style }
        target={ linkTarget }
      >
        { icon }
      </a>
    );
  }
  return <span className="userimage UserImage" style={ style }>{ icon }</span>;
};

UserImage.propTypes = {
  user: PropTypes.object,
  linkTarget: PropTypes.string
};

UserImage.defaultProps = {
  linkTarget: "_self"
};

export default UserImage;
