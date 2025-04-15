import React from "react";
import PropTypes from "prop-types";
import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const UserWithIcon = ( {
  config,
  hideSubtitle,
  skipSubtitleLink,
  subtitle,
  subtitleLinkOverwrite,
  subtitleIconClass,
  user
} ) => {
  if ( !user ) { return ( <div /> ); }

  const subtitleContent = (
    <>
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
    </>
  );
  const subtitleLinkDefault = `/observations?user_id=${user.login}&place_id=any&verifiable=any`;
  const subtitleLink = skipSubtitleLink
    ? subtitleContent
    : <a href={subtitleLinkOverwrite || subtitleLinkDefault}>{ subtitleContent }</a>;

  return (
    <div className="UserWithIcon">
      <div className="icon">
        <UserImage user={user} />
      </div>
      <div className="title-subtitle">
        <div className="title">
          <UserLink config={config} user={user} uniqueKey={`UserWithIcon-${user.id}`} />
        </div>
        { !hideSubtitle && (
          <div className="subtitle">{ subtitleLink }</div>
        ) }
      </div>
    </div>
  );
};

UserWithIcon.propTypes = {
  config: PropTypes.object,
  user: PropTypes.object,
  subtitle: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number
  ] ),
  subtitleLinkOverwrite: PropTypes.string,
  subtitleIconClass: PropTypes.string,
  hideSubtitle: PropTypes.bool,
  skipSubtitleLink: PropTypes.bool
};

UserWithIcon.defaultProps = {
  subtitleIconClass: "fa fa-binoculars"
};

export default UserWithIcon;
