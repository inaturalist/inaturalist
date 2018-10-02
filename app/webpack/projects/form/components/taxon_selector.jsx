import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import util from "../../../observations/show/util";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";
import SplitTaxon from "../../../shared/components/split_taxon";

class TaxonSelector extends React.Component {
  render( ) {
    const {
      config,
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse ?
      I18n.t( "exclude_x", { x: I18n.t( "taxa" ) } ) : I18n.t( "taxa" );
    const rule = inverse ? "not_in_taxon?" : "in_taxon?";
    const rulesAttribute = inverse ? "notTaxonRules" : "taxonRules";
    return (
      <div className="TaxonSelector">
        <label>{ label }</label>
        <TaxonAutocomplete
          ref="ta"
          bootstrap
          perPage={ 6 }
          searchExternal={ false }
          onSelectReturn={ e => {
            addProjectRule( rule, "Taxon", e.item );
            this.refs.ta.inputElement( ).val( "" );
          } }
          config={ config }
          placeholder={ I18n.t( "taxon_autocomplete_placeholder" ) }
        />
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], taxonRule => (
              <div className="icon-preview" key={ `taxon_rule_${taxonRule.taxon.id}` }>
                { util.taxonImage( taxonRule.taxon ) }
                <SplitTaxon
                  taxon={ taxonRule.taxon }
                  user={ config.currentUser }
                />
                <i
                  className="fa fa-times-circle"
                  onClick={ ( ) => removeProjectRule( taxonRule ) }
                />
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
