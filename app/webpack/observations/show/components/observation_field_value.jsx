import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";

const ObservationFieldValue = ( { ofv } ) => {
  if ( !ofv ) { return ( <div /> ); }
  let value = ofv.value;
  if ( ofv.datatype === "dna" ) {
    value = ( <div className="dna">{ ofv.value }</div> );
  } else if ( ofv.datatype === "taxon" && ofv.taxon ) {
    value = ( <SplitTaxon
      taxon={ ofv.taxon }
      url={ `/taxa/${ofv.taxon.id}` }
    /> );
  }
  return (
    <div className="ObservationFieldValue" key={ ofv.uuid }>
      <div className="field">
        <a href={ `/observation_fields/${ofv.field_id}` }>
          { ofv.name }:
        </a>
      </div>
      <div className="value">{ value }</div>
    </div>
  );
};

ObservationFieldValue.propTypes = {
  ofv: PropTypes.object
};

export default ObservationFieldValue;
