import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

class PlaceSelector extends React.Component {
  render( ) {
    const {
      config,
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse ?
      I18n.t( "except_x", { x: I18n.t( "places" ) } ) : I18n.t( "places" );
    const rule = inverse ? "not_observed_in_place?" : "observed_in_place?";
    const rulesAttribute = inverse ? "notPlaceRules" : "placeRules";
    return (
      <div className="PlaceSelector">
        <label>{ label }</label>
        <div className="input-group">
          <span className="input-group-addon fa fa-globe"></span>
          <PlaceAutocomplete
            ref="pa"
            afterSelect={ e => {
              addProjectRule( rule, "Place", e.item );
              this.refs.pa.inputElement( ).val( "" );
            } }
            bootstrapClear
            config={ config }
            placeholder={ I18n.t( "place_autocomplete_placeholder" ) }
          />
        </div>
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], placeRule => (
              <div className="badge-div" key={ `place_rule_${placeRule.place.id}` }>
                <span className="badge">
                  { placeRule.place.display_name }
                  <i
                    className="fa fa-times-circle-o"
                    onClick={ ( ) => removeProjectRule( placeRule ) }
                  />
                </span>
              </div>
            ) ) }
          </div>
        ) }
      </div>
    );
  }
}

PlaceSelector.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func,
  inverse: PropTypes.boolean
};

export default PlaceSelector;
