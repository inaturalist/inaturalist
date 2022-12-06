import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import SettingsItem from "./settings_item";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

/* global TAXON_NAME_LEXICONS */

class TaxonNamePreferences extends Component {
  constructor( ) {
    super( );
    this.state = { };
  }

  taxonNamePreferenceLexicons( ) {
    return _.map( TAXON_NAME_LEXICONS, ( lexicon, parameterizedLexicon ) => (
      <option value={parameterizedLexicon} key={parameterizedLexicon}>
        {lexicon}
      </option>
    ) );
  }

  render( ) {
    const {
      profile,
      config,
      addTaxonNamePreference,
      deleteTaxonNamePreference
    } = this.props;
    return (
      <div>
        <SettingsItem header="Taxon Name Preferences" htmlFor="taxon_name_preferences">
          <table className="table">
            <thead>
              <tr>
                <th>Position</th>
                <th>Lexicon</th>
                <th>Place</th>
                <th>Delete</th>
              </tr>
            </thead>
            <tbody>
              { ( profile.taxon_name_preferences || [] ).map( ( taxonNamePreference, index ) => (
                <tr key={`taxon-name-preference-${taxonNamePreference.id}`}>
                  <td>{ taxonNamePreference.position }</td>
                  <td>{ taxonNamePreference.lexicon }</td>
                  <td>{ taxonNamePreference.place_id }</td>
                  <td>
                    { index > 0 && (
                      <button
                        type="button"
                        onClick={( ) => deleteTaxonNamePreference( taxonNamePreference.id )}
                      >
                        Delete
                      </button>
                    ) }
                  </td>
                </tr>
              ) ) }
            </tbody>
          </table>
          <select
            id="user_locale"
            className="form-control dropdown"
            name="lexicon"
            onChange={e => { this.state.selectedLexicon = e.target.value; }}
          >
            <option value={null} key="no-lexicon">
              -- Select --
            </option>
            { this.taxonNamePreferenceLexicons( ) }
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
            onClick={( ) => addTaxonNamePreference(
              this.state.selectedLexicon,
              this.state.selectedPlaceID
            )}
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
  profile: PropTypes.object,
  config: PropTypes.object,
  addTaxonNamePreference: PropTypes.func,
  deleteTaxonNamePreference: PropTypes.func
};

export default TaxonNamePreferences;
