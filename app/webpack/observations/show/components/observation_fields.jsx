import _ from "lodash";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";

class ObservationFields extends React.Component {

  render( ) {
    const observation = this.props.observation;
    if ( !observation || _.isEmpty( observation.ofvs ) ) { return ( <div /> ); }
    const sortedFieldValues = _.sortBy( observation.ofvs, ofv => (
      `${ofv.value ? "a" : "z"}:${ofv.name}:${ofv.value}`
    ) );
    return (
      <div className="ObservationFields">
        <h4>Observation Fields</h4>
        {
          sortedFieldValues.map( ofv => {
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
              <div className="field-value" key={ ofv.uuid }>
                <div className="field">
                  <a href={ `/observation_fields/${ofv.field_id}` }>
                    { ofv.name }:
                  </a>
                </div>
                <div className="value">{ value }</div>
              </div>
            );
          } )
        }
      </div>
    );
  }
}

ObservationFields.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object
};

export default ObservationFields;
