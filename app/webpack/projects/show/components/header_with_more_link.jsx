import React from "react";
import PropTypes from "prop-types";

const HeaderWithMoreLink = ( {
  children,
  href,
  nolink,
  onClick
} ) => {
  let link;
  if ( !nolink ) {
    if ( onClick ) {
      link = (
        <button
          type="button"
          className="btn btn-nostyle"
          onClick={onClick}
          aria-label={I18n.t( "view_more" )}
        >
          <i className="fa fa-arrow-circle-right" />
        </button>
      );
    } else {
      link = (
        <a href={href} aria-label={I18n.t( "view_more" )}>
          <i className="fa fa-arrow-circle-right" />
        </a>
      );
    }
  }
  return (
    <h2 className="HeaderWithMoreLink">
      <span>{ children }</span>
      { link }
    </h2>
  );
};

HeaderWithMoreLink.propTypes = {
  children: PropTypes.any,
  href: PropTypes.string,
  nolink: PropTypes.bool,
  onClick: PropTypes.func
};

export default HeaderWithMoreLink;
