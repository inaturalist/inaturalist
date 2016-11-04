import React, { PropTypes } from "react";
import CoverImage from "./cover_image";

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
      <a
        href={linkUrl}
        className="btn btn-primary btn-inat btn-xs"
      >
        { linkText }
      </a> {
        valueIconClassName ? <i className={valueIconClassName} /> : extra
      } {
        value ? <span className="value">{ I18n.toNumber( value, { precision: 0 } ) }</span> : null
      }
    </div>
  );
  return (
    <div className={`LeaderItem media ${noContent ? "no-content" : ""} ${className}`}>
      <div className="item-label">{ label }</div>
      <div className="media-left">
        <div className={`img-wrapper ${imageUrl ? "photo" : "no-photo"}`}>
          <a href={url}>
            {
              imageUrl ?
              <CoverImage src={imageUrl} height={56} />
              :
              <i className={iconClassName} />
            }
          </a>
        </div>
      </div>
      <div className="media-body">
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
