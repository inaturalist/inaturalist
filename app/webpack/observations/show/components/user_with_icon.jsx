import React from "react";
import PropTypes from "prop-types";
import UserImage from "../../../shared/components/user_image";

const UserWithIcon = ( { user, subtitle, subtitleIconClass } ) => {
  if ( !user ) { return ( <div /> ); }
  return (
    <div className="UserWithIcon">
      <div className="icon">
        <UserImage user={user} />
      </div>
      <div className="title">
        <a href={`/people/${user.login}`}>{ user.login }</a>
      </div>
      <div className="subtitle">
        <a href={`/observations?user_id=${user.login}&place_id=any&verifiable=any`}>
          <i className={subtitleIconClass} />
          {
            subtitle
            || (
              user.observations_count
              && I18n.t( "x_observations", { count: user.observations_count.toLocaleString( ) } )
            )
           }
        </a>
      </div>
    </div>
  );
};

UserWithIcon.propTypes = {
  user: PropTypes.object,
  subtitle: PropTypes.string,
  subtitleIconClass: PropTypes.string
};

UserWithIcon.defaultProps = {
  subtitleIconClass: "fa fa-binoculars"
};

export default UserWithIcon;
