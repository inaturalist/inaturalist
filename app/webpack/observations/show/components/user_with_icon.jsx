import React from "react";
import PropTypes from "prop-types";
import UserImage from "../../../shared/components/user_image";

const UserWithIcon = ( {
  hideSubtitle,
  subtitle,
  subtitleIconClass,
  user
} ) => {
  if ( !user ) { return ( <div /> ); }
  return (
    <div className="UserWithIcon">
      <div className="icon">
        <UserImage user={user} />
      </div>
      <div className="title-subtitle">
        <div className="title">
          <a href={`/people/${user.login}`}>{ user.login }</a>
        </div>
        { !hideSubtitle && (
          <div className="subtitle">
            <a href={`/observations?user_id=${user.login}&place_id=any&verifiable=any`}>
              <i className={subtitleIconClass} />
              {
                subtitle
                || (
                  user.observations_count
                  && I18n.t( "x_observations", {
                    count: I18n.toNumber( user.observations_count, { precision: 0 } )
                  } )
                )
               }
            </a>
          </div>
        ) }
      </div>
    </div>
  );
};

UserWithIcon.propTypes = {
  user: PropTypes.object,
  subtitle: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number
  ] ),
  subtitleIconClass: PropTypes.string,
  hideSubtitle: PropTypes.bool
};

UserWithIcon.defaultProps = {
  subtitleIconClass: "fa fa-binoculars"
};

export default UserWithIcon;
