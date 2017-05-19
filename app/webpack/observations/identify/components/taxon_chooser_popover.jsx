import React, { PropTypes } from "react";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import _ from "lodash";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";

const TaxonChooserPopover = ( {
  container,
  taxon,
  className,
  setTaxon,
  clearTaxon,
  preIconClass,
  postIconClass
} ) => (
  <OverlayTrigger
    trigger="click"
    placement="bottom"
    rootClose
    container={container}
    overlay={
      <Popover className="TaxonChooserPopover">
        <TaxonAutocomplete
          initialSelection={taxon}
          bootstrapClear
          searchExternal={false}
          resetOnChange={false}
          afterSelect={ result => {
            setTaxon( result.item );
            $( "body" ).click( );
          } }
          afterUnselect={ ( ) => {
            clearTaxon( );
            $( "body" ).click( );
          } }
        />
      </Popover>
    }
  >
    <div
      className={`TaxonChooserPopoverTrigger ${taxon ? "chosen" : ""} ${className}`}
    >
      { preIconClass ? <i className={`${preIconClass} pre-icon`}></i> : null }
      {
        taxon ?
          <SplitTaxon taxon={taxon} />
          :
          _.startCase( I18n.t( "filter_by_taxon" ) ) }
      { postIconClass ? <i className={`${postIconClass} post-icon`}></i> : null }
    </div>
  </OverlayTrigger>
);

TaxonChooserPopover.propTypes = {
  container: PropTypes.object,
  taxon: PropTypes.object,
  className: PropTypes.string,
  setTaxon: PropTypes.func,
  clearTaxon: PropTypes.func,
  preIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  postIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] )
};

TaxonChooserPopover.defaultProps = {
  preIconClass: "fa fa-search"
};

export default TaxonChooserPopover;
