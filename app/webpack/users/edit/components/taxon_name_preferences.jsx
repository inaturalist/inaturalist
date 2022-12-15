import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import SettingsItem from "./settings_item";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";
import TaxonNamePreferencesDragdropContainer from "../containers/taxon_name_preferences_dragdrop_container";

/* global TAXON_NAME_LEXICONS */

class TaxonNamePreferences extends Component {
  static taxonNamePreferenceLexicons( ) {
    return _.map( TAXON_NAME_LEXICONS, ( lexicon, parameterizedLexicon ) => (
      <option value={parameterizedLexicon} key={parameterizedLexicon}>
        {lexicon}
      </option>
    ) );
  }

  constructor( ) {
    super( );
    this.state = { };
  }

  render( ) {
    const {
      config,
      addTaxonNamePreference
    } = this.props;
    return (
      <div className="TaxonNamePreferences">
        <SettingsItem header="Taxon Name Preferences" htmlFor="taxon_name_preferences">
          <TaxonNamePreferencesDragdropContainer />
          <select
            id="user_locale"
            className="form-control dropdown"
            name="lexicon"
            onChange={e => { this.state.selectedLexicon = e.target.value === "locale" ? null : e.target.value; }}
          >
            <option value={undefined} key="no-lexicon">
              -- Select --
            </option>
            <option value="locale" key="dynamic-lexicon">
              Same as locale
            </option>
            { TaxonNamePreferences.taxonNamePreferenceLexicons( ) }
          </select>
          <PlaceAutocomplete
            config={config}
            resetOnChange
            bootstrapClear
            afterSelect={e => { this.state.selectedPlaceID = e.item.id; }}
            afterClear={( ) => { this.state.selectedPlaceID = null; }}
          />
          <button
            type="button"
            onClick={( ) => {
              if ( !_.isUndefined( this.state.selectedLexicon ) ) {
                addTaxonNamePreference(
                  this.state.selectedLexicon,
                  this.state.selectedPlaceID
                );
              }
            }}
          >
            Add New Taxon Name Preference
          </button>
        </SettingsItem>
        <p
          className="text-muted"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{ __html: "Taxon name preferences" }}
        />
      </div>
    );
  }
}

TaxonNamePreferences.propTypes = {
  config: PropTypes.object,
  addTaxonNamePreference: PropTypes.func
};

export default TaxonNamePreferences;
