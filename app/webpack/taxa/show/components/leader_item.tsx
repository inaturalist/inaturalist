import React from "react";
import _ from "lodash";
import CoverImage from "../../../shared/components/cover_image";
import taxaShowResponsive from "../responsive";
import LeaderItemLegacy from "./leader_item_legacy";

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

const LeaderItemResponsive = ( {
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
      <span className="icon-value">
        { valueIconClassName ? <i className={valueIconClassName} /> : extra }
        { " " }
        { value ? <span className="value">{ I18n.toNumber( value, { precision: 0 } ) }</span> : null }
      </span>
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

// Renders the pre-WEB-984 layout unless the user is testing responsiveness.
// The legacy module is untyped JS, so its props are asserted to match.
type GateProps = React.ComponentProps<typeof LeaderItemResponsive>;
const LegacyFallback = LeaderItemLegacy as unknown as React.ComponentType<GateProps>;

/* eslint-disable react/jsx-props-no-spreading */
const LeaderItem = ( props: GateProps ) => (
  taxaShowResponsive( )
    ? <LeaderItemResponsive {...props} />
    : <LegacyFallback {...props} />
);
/* eslint-enable react/jsx-props-no-spreading */

export default LeaderItem;
