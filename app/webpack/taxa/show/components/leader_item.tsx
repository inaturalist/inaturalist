import React from "react";
import _ from "lodash";
import CoverImage from "../../../shared/components/cover_image";

interface LeaderItemProps {
  noContent?: boolean;
  className?: string;
  label?: string;
  labelTooltip?: string;
  name?: string | number;
  imageUrl?: string;
  iconClassName?: string;
  value?: number;
  valueIconClassName?: string;
  extra?: string;
  linkText?: string;
  linkUrl?: string;
  url?: string;
  extraLinkUrl?: string;
  extraLinkText?: string;
  extraLinkTextShort?: string;
  onClickUrl?: ( payload: unknown ) => void;
  onClickUrlPayload?: Record<string, unknown>;
}

const LeaderItem = ( {
  noContent,
  className = "",
  label,
  labelTooltip,
  name,
  imageUrl,
  iconClassName = "icon-species-unknown",
  value,
  valueIconClassName,
  extra,
  linkText = I18n.t( "view" ),
  linkUrl,
  url,
  extraLinkUrl,
  extraLinkText,
  extraLinkTextShort,
  onClickUrl,
  onClickUrlPayload
}: LeaderItemProps ) => {
  const handleClick = ( e: React.MouseEvent<HTMLAnchorElement> ) => {
    if ( !onClickUrl ) return;
    if ( e.metaKey || e.ctrlKey ) return;
    e.preventDefault( );
    onClickUrl( onClickUrlPayload );
  };

  const nameStr = name != null ? String( name ) : "";

  const extraContent = (
    <div className="extra">
      <a href={linkUrl} className="btn btn-primary btn-inat btn-xs">
        { linkText }
      </a>
      { " " }
      { extraLinkUrl ? (
        <a href={extraLinkUrl} className="btn btn-default btn-inat btn-outline btn-xs">
          <span className="show-below-lg">{ extraLinkTextShort || extraLinkText }</span>
          <span className="show-lg-up">{ extraLinkText }</span>
        </a>
      ) : null }
      { " " }
      { valueIconClassName ? <i className={valueIconClassName} /> : extra }
      { " " }
      { value ? <span className="value">{ I18n.toNumber( value, { precision: 0 } ) }</span> : null }
    </div>
  );

  return (
    <div className={`LeaderItem ${noContent ? "no-content" : ""} ${className}`}>
      <div className="item-label" title={labelTooltip}>{ label }</div>
      <div className="leader-item-media">
        <div className={`img-wrapper ${imageUrl ? "photo" : "no-photo"}`}>
          <a href={url} onClick={handleClick}>
            { imageUrl
              ? <CoverImage src={imageUrl} height={56} />
              : <i className={iconClassName} /> }
          </a>
        </div>
        <div className="leader-item-body">
          <h4 className="name">
            <a title={nameStr} href={url} onClick={handleClick}>
              <span className="show-below-lg">{ _.truncate( nameStr, { length: 16 } ) }</span>
              <span className="show-lg-up">{ _.truncate( nameStr, { length: 27 } ) }</span>
            </a>
          </h4>
          { noContent ? null : extraContent }
        </div>
      </div>
    </div>
  );
};

export default LeaderItem;
