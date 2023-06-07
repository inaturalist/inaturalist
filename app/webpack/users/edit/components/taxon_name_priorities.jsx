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
        <SettingsItem header="Common Name Priorities" htmlFor="taxon_name_priorities">
          <div className="alert alert-warning text-center">
            Admin-only preview
          </div>
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: "Enter common name lexicons and an optional place to"
                + " customize how common names are localized and prioritized for display."
                + " Drag and drop rows to change the priority order"
            }}
          />
          <TaxonNamePrioritiesDragdropContainer />
        </SettingsItem>
        { ( _.size( taxonNamePriorities ) < 3 ) && (
          <SettingsItem header="Add A Common Name Priority" htmlFor="add_taxon_name_priorities">
            <select
              id="user_locale"
              className="form-control dropdown"
              name="lexicon"
              onChange={e => { this.state.selectedLexicon = e.target.value === "locale" ? null : e.target.value; }}
            >
              <option value={undefined} key="no-lexicon">
                -- Select a lexicon --
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
            <button
              type="button"
              onClick={( ) => {
                if ( !_.isUndefined( this.state.selectedLexicon ) ) {
                  addTaxonNamePriority(
                    this.state.selectedLexicon,
                    this.state.selectedPlaceID
                  );
                }
              }}
            >
              Create Common Name Priority
            </button>
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
