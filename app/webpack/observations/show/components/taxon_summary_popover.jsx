import React from "react";
import PropTypes from "prop-types";
import { Popover, OverlayTrigger } from "react-bootstrap";
import util from "../util";

const TaxonSummaryPopover = ( { taxon, contents } ) => {
  if ( !taxon ) {
    return ( <div /> );
  }
  const taxonImageTag = util.taxonImage( taxon, { size: "medium" } );
  const popover = (
    <Popover
      className="TaxonSummaryPopoverOverlay"
      id={ `popover-taxon-${taxon.id}` }
    >
      <div>
        <div className="photo">
          <a href={ `/taxa/${taxon.id}` }>
            { taxonImageTag }
          </a>
        </div>
        <div className="summary">
          <span dangerouslySetInnerHTML={ { __html: (
            taxon.taxon_summary && taxon.taxon_summary.wikipedia_summary ?
            taxon.taxon_summary.wikipedia_summary : I18n.t( "no_summary_from_wikipedia" ) ) } }
          />
        <a href={ `/taxa/${taxon.id}` } className="more">
          <button className="btn btn-default">
            <i className="fa fa-info-circle" /> { I18n.t( "more_info" ) }
          </button>
        </a>
        </div>
      </div>
    </Popover>
  );
  return (
    <OverlayTrigger
      trigger="click"
      rootClose
      placement="top"
      animation={false}
      overlay={popover}
      containerPadding={ 20 }
    >
      <span className="TaxonSummaryPopover">
        { contents }
      </span>
    </OverlayTrigger>
  );
};

TaxonSummaryPopover.propTypes = {
  contents: PropTypes.object,
  taxon: PropTypes.object
};

export default TaxonSummaryPopover;
