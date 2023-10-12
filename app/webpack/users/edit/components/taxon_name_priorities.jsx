import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
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
        <SettingsItem header="Common Name Lexicons" htmlFor="taxon_names_display">
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: "By default, common names are displayed in your account language/locale. To see names in other lexicons, or to prioritize names used in specific places (such as English (Australia) or Spanish (Costa Rica)), add common name lexions. A maximum of 3 common names can be displayed at a time. If no common name exists for a lexicon you have chosen, it will be omitted from display."
            }}
          />
          { ( _.size( taxonNamePriorities ) < 3 ) ? (
            <div
              key={`lexicon-selector-${this.state.selectedLexicon}`}
            >
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
                  Same as user language/locale preference
                </option>
                { TaxonNamePriorities.taxonNamePriorityLexicons( ) }
              </select>
              <PlaceAutocomplete
                config={config}
                resetOnChange
                bootstrapClear
                afterSelect={e => { this.state.selectedPlaceID = e.item.id; }}
                afterClear={( ) => { this.state.selectedPlaceID = null; }}
                placeholder="Select a place (optional)"
              />
              <div className="add-button">
                <button
                  type="button"
                  className="btn btn-default btn-primary"
                  onClick={( ) => {
                    if ( !_.isUndefined( this.state.selectedLexicon ) ) {
                      addTaxonNamePriority(
                        this.state.selectedLexicon,
                        this.state.selectedPlaceID
                      );
                    }
                  }}
                >
                  Add a common name lexicon
                </button>
              </div>
            </div>
          ) : (
            <div className="alert alert-warning text-center">
              The maximum of 3 common name lexicons have already been added
            </div>
          )}
        </SettingsItem>
        { ( _.size( taxonNamePriorities ) > 0 ) && (
          <SettingsItem header="Common Name Lexicon Display Order" htmlFor="taxon_name_priorities">
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: "For multiple common name lexicons, drag and drop the settings below to customize the order in which they are displayed."
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
