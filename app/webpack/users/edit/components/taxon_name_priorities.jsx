import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import SettingsItem from "./settings_item";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";
import TaxonNamePrioritiesDragdropContainer from "../containers/taxon_name_priorities_dragdrop_container";

/* global TAXON_NAME_LEXICONS */

class TaxonNamePriorities extends Component {
  static taxonNamePriorityLexicons( ) {
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
      addTaxonNamePriority,
      taxonNamePriorities
    } = this.props;
    if ( !( config && config.currentUser && (
      config.currentUser.roles.indexOf( "admin" ) >= 0 || config.currentUser.sites_admined.length > 0 )
    ) ) {
      return null;
    }
    return (
      <div className="TaxonNamePriorities">
        <div className="alert alert-warning text-center">
          Admin-only preview
        </div>
        <SettingsItem header="Common Names Display" htmlFor="taxon_names_display">
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: "By default, common names will appear in the language associated with you language/locale settings. Enter common name lexions with an optional place to customize the common names you see across iNaturalist. You can display a maximum of 3 common names at a time, and if no common name exists for a lexicon you have chosen, it will be omitted in display."
            }}
          />
          { ( _.size( taxonNamePriorities ) < 3 ) && (
            <div>
              <select
                id="user_locale"
                className="form-control dropdown"
                name="lexicon"
                onChange={e => { this.state.selectedLexicon = e.target.value === "locale" ? null : e.target.value; }}
              >
                <option value={undefined} key="no-lexicon">
                  Select a lexicon
                </option>
                <option value="locale" key="dynamic-lexicon">
                  Same as user locale preference
                </option>
                { TaxonNamePriorities.taxonNamePriorityLexicons( ) }
              </select>
              <PlaceAutocomplete
                config={config}
                resetOnChange
                bootstrapClear
                afterSelect={e => { this.state.selectedPlaceID = e.item.id; }}
                afterClear={( ) => { this.state.selectedPlaceID = null; }}
                placeholder={I18n.t( "place_autocomplete_placeholder" )}
              />
              <div className="add-button">
                <button
                  type="button"
                  className="btn btn-default"
                  onClick={( ) => {
                    if ( !_.isUndefined( this.state.selectedLexicon ) ) {
                      addTaxonNamePriority(
                        this.state.selectedLexicon,
                        this.state.selectedPlaceID
                      );
                    }
                  }}
                >
                  Add a common name to display
                </button>
              </div>
            </div>
          ) }
        </SettingsItem>
        { ( _.size( taxonNamePriorities ) > 0 ) && (
          <SettingsItem header="Common Names Display Priority" htmlFor="taxon_name_priorities">
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: "For multiple common names, drag and drop the common name lexicons below to customize the order in while they are prioritized in display across iNaturalist."
              }}
            />
            <TaxonNamePrioritiesDragdropContainer />
          </SettingsItem>
        ) }
      </div>
    );
  }
}

TaxonNamePriorities.propTypes = {
  config: PropTypes.object,
  addTaxonNamePriority: PropTypes.func,
  taxonNamePriorities: PropTypes.array
};

export default TaxonNamePriorities;
