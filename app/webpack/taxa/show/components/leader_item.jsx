import React, { PropTypes } from "react";

const LeaderItem = ( {
  className,
  label,
  name,
  imageUrl,
  iconClassName,
  value,
  valueIconClassName,
  extra,
  linkText,
  linkUrl
} ) => (
  <div className={`LeaderItem media ${className}`}>
    <div className="media-left">
      <div className="img-wrapper">
        { imageUrl ? <img src={imageUrl} className="img-responsive" /> : <i className={iconClassName} /> }
      </div>
    </div>
    <div className="media-body">
      <h4>{ label ? `${label}:` : null} <span className="name">{ name }</span></h4>
      <div className="extra">
        {
          valueIconClassName ? <i className={valueIconClassName} /> : extra
        } {
          value ? <span className="value">{ value }</span> : null
        } <a
          href={linkUrl}
        >
          { linkText }
        </a>
      </div>
    </div>
  </div>
);

LeaderItem.propTypes = {
  className: PropTypes.string,
  label: PropTypes.string,
  name: React.PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number
  ] ),
  imageUrl: PropTypes.string,
  iconClassName: PropTypes.string,
  value: PropTypes.number,
  valueIconClassName: PropTypes.string,
  linkText: PropTypes.string,
  linkUrl: PropTypes.string,
  extra: PropTypes.string
};

LeaderItem.defaultProps = {
  iconClassName: "icon-species-unknown",
  linkText: I18n.t( "view" )
};

export default LeaderItem;
