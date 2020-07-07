import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

class PlaceSelector extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.placeAutocomplete = React.createRef( );
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
      ? I18n.t( "exclude_places" )
      : I18n.t( "include_places" );
    const rule = inverse ? "not_observed_in_place?" : "observed_in_place?";
    const rulesAttribute = inverse ? "notPlaceRules" : "placeRules";
    return (
      <div className="PlaceSelector">
        <label>{ label }</label>
        <div className="input-group">
          <span className="input-group-addon fa fa-globe" />
          <PlaceAutocomplete
            ref={this.placeAutocomplete}
            afterSelect={e => {
              addProjectRule( rule, "Place", e.item );
              this.placeAutocomplete.current.inputElement( ).val( "" );
            }}
            bootstrapClear
            config={config}
            placeholder={I18n.t( "place_autocomplete_placeholder" )}
          />
        </div>
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], placeRule => (
              <div className="badge-div" key={`place_rule_${placeRule.place.id}`}>
                <span className="badge">
                  { placeRule.place.display_name }
                  <button
                    type="button"
                    className="btn btn-nostyle"
                    onClick={( ) => removeProjectRule( placeRule )}
                  >
                    <i className="fa fa-times-circle-o" />
                  </button>
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
  inverse: PropTypes.bool
};

export default PlaceSelector;
