import React, { PropTypes } from "react";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

const TaxonThumbnail = ( { taxon, key } ) => {
  const img = taxon.defaultPhoto ? (
    <CoverImage
      src={taxon.defaultPhoto.photoUrl( "medium" )}
      low={taxon.defaultPhoto.photoUrl( "square" )}
      height={130}
      className="photo"
    />
  ) : (
    <div className="photo">
      <i
        className={
          `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
        }
      ></i>
    </div>
  );
  return (
    <div key={key} className="TaxonThumbnail thumbnail">
      <a href={urlForTaxon( taxon )}>{ img }</a>
      <div className="caption">
        <SplitTaxon taxon={taxon} url={urlForTaxon( taxon )} noParens truncate={15} />
      </div>
    </div>
  );
};

TaxonThumbnail.propTypes = {
  taxon: PropTypes.object.isRequired,
  key: PropTypes.string
};

export default TaxonThumbnail;
