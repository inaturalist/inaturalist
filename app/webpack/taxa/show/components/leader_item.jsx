import React, { PropTypes } from "react";

const LeaderItem = ( {
  noContent,
  className,
  label,
  name,
  imageUrl,
  iconClassName,
  value,
  valueIconClassName,
  extra,
  linkText,
  linkUrl,
  url
} ) => {
  const extraContent = (
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
  );
  return (
    <div className={`LeaderItem media ${noContent ? "no-content" : ""} ${className}`}>
      <div className="media-left">
        <div className="img-wrapper">
          <a href={url}>
            {
              imageUrl ?
              <img src={imageUrl} className="img-responsive" />
              :
              <i className={iconClassName} />
            }
          </a>
        </div>
      </div>
      <div className="media-body">
        <div className="item-label">{ label }</div>
        <h4 className="name"><a href={url}>{ name }</a></h4>
        { noContent ? null : extraContent }
      </div>
    </div>
  );
};

LeaderItem.propTypes = {
  noContent: PropTypes.bool,
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
  extra: PropTypes.string,
  url: PropTypes.string
};

LeaderItem.defaultProps = {
  iconClassName: "icon-species-unknown",
  linkText: I18n.t( "view" )
};

export default LeaderItem;
