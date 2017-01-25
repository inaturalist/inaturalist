import React, { PropTypes } from "react";
import { OverlayTrigger, Tooltip } from "react-bootstrap";
import CoverImage from "../../../shared/components/cover_image";
import _ from "lodash";

const LeaderItem = ( {
  noContent,
  className,
  label,
  labelTooltip,
  name,
  imageUrl,
  iconClassName,
  value,
  valueIconClassName,
  extra,
  linkText,
  linkUrl,
  url,
  extraLinkUrl,
  extraLinkText,
  extraLinkTextShort,
  onClickUrl,
  onClickUrlPayload
} ) => {
  const extraContent = (
    <div className="extra">
      <a
        href={linkUrl}
        className="btn btn-primary btn-inat btn-xs"
      >
        { linkText }
      </a> {
        extraLinkUrl ?
          (
            <a href={extraLinkUrl} className="btn btn-default btn-inat btn-xs">
              <span className="hidden-lg">{ extraLinkTextShort || extraLinkText }</span>
              <span className="hidden-xs hidden-sm hidden-md">{ extraLinkText }</span>
            </a>
          )
          :
          null
      } {
        valueIconClassName ? <i className={valueIconClassName} /> : extra
      } {
        value ? <span className="value">{ I18n.toNumber( value, { precision: 0 } ) }</span> : null
      }
    </div>
  );
  const itemLabelContent = <div className="item-label">{ label }</div>;
  let itemLabel = itemLabelContent;
  if ( labelTooltip ) {
    itemLabel = (
      <OverlayTrigger
        placement="top"
        delayShow={1000}
        container={ $( "#wrapper.bootstrap" ).get( 0 ) }
        overlay={
          <Tooltip id={`leader-item-label-${className}`}>
            { labelTooltip }
          </Tooltip>
        }
      >
        { itemLabelContent }
      </OverlayTrigger>
    );
  }
  return (
    <div className={`LeaderItem media ${noContent ? "no-content" : ""} ${className}`}>
      { itemLabel }
      <div className="media-left">
        <div className={`img-wrapper ${imageUrl ? "photo" : "no-photo"}`}>
          <a
            href={url}
            onClick={ e => {
              if ( !onClickUrl ) return true;
              if ( e.metaKey || e.ctrlKey ) return true;
              e.preventDefault( );
              onClickUrl( onClickUrlPayload );
              return false;
            } }
          >
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
        <h4 className="name">
          <a
            title={name}
            href={url}
            onClick={ e => {
              if ( !onClickUrl ) return true;
              if ( e.metaKey || e.ctrlKey ) return true;
              e.preventDefault( );
              onClickUrl( onClickUrlPayload );
              return false;
            } }
          >
            <span className=".visible-xs-inline visible-sm-inline visible-md-inline">
              { _.truncate( name, { length: 16 } ) }
            </span>
            <span className="visible-lg-inline">{ _.truncate( name, { length: 27 } ) }</span>
          </a>
        </h4>
        { noContent ? null : extraContent }
      </div>
    </div>
  );
};

LeaderItem.propTypes = {
  noContent: PropTypes.bool,
  className: PropTypes.string,
  label: PropTypes.string,
  labelTooltip: PropTypes.string,
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
  url: PropTypes.string,
  extraLinkUrl: PropTypes.string,
  extraLinkText: PropTypes.string,
  extraLinkTextShort: PropTypes.string,
  onClickUrl: PropTypes.func,
  onClickUrlPayload: PropTypes.object
};

LeaderItem.defaultProps = {
  iconClassName: "icon-species-unknown",
  linkText: I18n.t( "view" )
};

export default LeaderItem;
