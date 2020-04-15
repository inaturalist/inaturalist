import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import util from "../../../observations/show/util";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";
import SplitTaxon from "../../../shared/components/split_taxon";

/* global ROOT_TAXON_ID */

class TaxonSelector extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.taxonAutocomplete = React.createRef( );
  }

  render( ) {
    const {
      config,
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse
      ? I18n.t( "exclude_taxa" )
      : I18n.t( "include_taxa" );
    const rule = inverse ? "not_in_taxon?" : "in_taxon?";
    const rulesAttribute = inverse ? "notTaxonRules" : "taxonRules";
    const notIDs = [ROOT_TAXON_ID].concat( _.map( project[rulesAttribute], r => r.taxon.id ) );
    return (
      <div className="TaxonSelector">
        <label>{ label }</label>
        <TaxonAutocomplete
          ref={this.taxonAutocomplete}
          bootstrap
          perPage={6}
          searchExternal={false}
          onSelectReturn={e => {
            addProjectRule( rule, "Taxon", e.item );
            this.taxonAutocomplete.current.inputElement( ).val( "" );
          }}
          notIDs={notIDs}
          config={config}
          placeholder={I18n.t( "taxon_autocomplete_placeholder" )}
        />
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], taxonRule => (
              <div className="icon-preview" key={`taxon_rule_${taxonRule.taxon.id}`}>
                { util.taxonImage( taxonRule.taxon ) }
                <SplitTaxon
                  taxon={taxonRule.taxon}
                  user={config.currentUser}
                />
                <button
                  type="button"
                  className="btn btn-nostyle"
                  onClick={( ) => removeProjectRule( taxonRule )}
                >
                  <i className="fa fa-times-circle" />
                </button>
              </div>
            ) ) }
          </div>
        ) }
      </div>
    );
  }
}

TaxonSelector.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func,
  inverse: PropTypes.bool
};

export default TaxonSelector;
