import React from "react";
import PropTypes from "prop-types";
import { OverlayTrigger, Tooltip } from "react-bootstrap";
import _ from "lodash";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon as utilUrlForTaxon } from "../../shared/util";

const TaxonThumbnail = ( {
  taxon,
  key,
  badgeText,
  badgeTip,
  height,
  truncate,
  onClick,
  captionForTaxon,
  urlForTaxon,
  overlay,
  config,
  noInactive
} ) => {
  let mediumURL;
  let squareURL;
  if ( taxon.defaultPhoto && _.isFunction( taxon.defaultPhoto.constructor ) ) {
    mediumURL = taxon.defaultPhoto.photoUrl( "medium" );
    squareURL = taxon.defaultPhoto.photoUrl( "square" );
  } else if ( _.isObject( taxon.default_photo ) ) {
    mediumURL = taxon.default_photo.medium_url;
    squareURL = taxon.default_photo.square_url;
  }
  const img = mediumURL ? (
    <CoverImage
      src={mediumURL}
      low={squareURL}
      height={height}
      className="photo"
    />
  ) : (
    <div className="photo" style={{ height, lineHeight: `${height}px` }}>
      <i
        className={
          `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
        }
      ></i>
    </div>
  );
  let badge;
  if ( badgeText ) {
    const badgeSpan = <span className={`badge ${badgeTip ? "with-tip" : ""}`}>{ badgeText }</span>;
    if ( badgeTip ) {
      badge = (
        <OverlayTrigger
          placement="top"
          overlay={
            <Tooltip id={`taxon-thumbnail-badge-${taxon.id}-${_.snakeCase( badgeText )}`}>
              { badgeTip }
            </Tooltip>
          }
          container={ $( "#wrapper.bootstrap" ).get( 0 ) }
        >
          { badgeSpan }
        </OverlayTrigger>
      );
    } else {
      badge = badgeSpan;
    }
  }
  let overlayDiv;
  if ( overlay ) {
    overlayDiv = ( <div className="overlay">{ overlay }</div > );
  }
  return (
    <div key={key} className="TaxonThumbnail thumbnail">
      { badge }
      <a href={urlForTaxon( taxon )} onClick={onClick}>{ img }</a>
      { overlayDiv }
      <div className="caption">
        <SplitTaxon
          taxon={taxon}
          url={urlForTaxon( taxon )}
          noParens
          truncate={truncate}
          onClick={onClick}
          user={ config.currentUser }
          noInactive={ noInactive }
        />
        { captionForTaxon ? captionForTaxon( taxon ) : null }
      </div>
    </div>
  );
};

TaxonThumbnail.propTypes = {
  taxon: PropTypes.object.isRequired,
  key: PropTypes.string,
  badgeText: PropTypes.oneOfType( [
    PropTypes.object,
    PropTypes.string,
    PropTypes.number
  ] ),
  badgeTip: PropTypes.string,
  height: PropTypes.number,
  truncate: PropTypes.number,
  onClick: PropTypes.func,
  captionForTaxon: PropTypes.func,
  urlForTaxon: PropTypes.func,
  overlay: PropTypes.object,
  config: PropTypes.object,
  noInactive: PropTypes.bool
};

TaxonThumbnail.defaultProps = {
  height: 130,
  truncate: 15,
  urlForTaxon: utilUrlForTaxon,
  config: {}
};

export default TaxonThumbnail;
