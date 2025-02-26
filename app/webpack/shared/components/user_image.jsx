import React from "react";
import PropTypes from "prop-types";

const WIDTHS = {
  original: 2048,
  large: 500,
  medium: 300,
  thumb: 48,
  mini: 16
};

function getUserIconUrl2x( iconUrl ) {
  if ( !iconUrl ) return null;
  const matches = iconUrl.match( /(mini|thumb|medium|large|original)\.\w+/ );
  if ( !matches ) return null;
  if ( matches.length < 2 ) return null;
  const size = matches[1];
  if ( !size ) return null;
  const width = WIDTHS[size];
  const size2x = Object
    .keys( WIDTHS )
    .toSorted( ( a, b ) => WIDTHS[a] - WIDTHS[b] )
    .find( sizeName => WIDTHS[sizeName] >= width * 2 );
  if ( !size2x ) return null;
  return iconUrl.replace( size, size2x );
}

function getUserBackgroundStyle( user, options = {} ) {
  if ( !user ) return {};
  if ( !user.icon_url ) return {};
  const size = options.size || "medium";
  const iconUrl = user.icon_url.replace( /(mini|thumb|medium|large|original)/, size );
  let backgroundImage = `url( ${iconUrl} )`;
  const iconUrl2x = getUserIconUrl2x( iconUrl );
  if ( iconUrl2x ) {
    backgroundImage = `url( ${iconUrl2x} ), ${backgroundImage}`;
  }
  return { backgroundImage };
}

const UserImage = ( { linkTarget, size, user } ) => {
  const icon = (
    <i
      className="icon-person"
      style={{
        display: user && user.icon_url ? "none" : "inline-block"
      }}
    />
  );
  if ( user ) {
    return (
      <a
        className="userimage UserImage"
        href={`/people/${user.login || user.id}`}
        title={user.login}
        style={getUserBackgroundStyle( user, { size } )}
        target={linkTarget}
        rel={linkTarget === "_blank" ? "noopener noreferrer" : null}
      >
        { icon }
      </a>
    );
  }
  return <span className="userimage UserImage">{ icon }</span>;
};

UserImage.propTypes = {
  linkTarget: PropTypes.string,
  size: PropTypes.string,
  user: PropTypes.object
};

UserImage.defaultProps = {
  linkTarget: "_self",
  size: "thumb"
};

export default UserImage;
