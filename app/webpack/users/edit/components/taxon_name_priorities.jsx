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
    return (
      <div className="TaxonNamePriorities">
        <SettingsItem
          header={I18n.t( "views.users.edit.taxon_name_priorities.common_name_lexicons" )}
          htmlFor="taxon_names_display"
        >
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.users.edit.taxon_name_priorities.common_name_lexicons_description" )
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
                  { I18n.t( "views.users.edit.taxon_name_priorities.select_a_lexicon" ) }
                </option>
                <option value="locale" key="dynamic-lexicon">
                  { I18n.t( "views.users.edit.taxon_name_priorities.same_as_language_locale_preference" ) }
                </option>
                { TaxonNamePriorities.taxonNamePriorityLexicons( ) }
              </select>
              <PlaceAutocomplete
                config={config}
                resetOnChange
                bootstrapClear
                afterSelect={e => { this.state.selectedPlaceID = e.item.id; }}
                afterClear={( ) => { this.state.selectedPlaceID = null; }}
                placeholder={I18n.t( "views.users.edit.taxon_name_priorities.add_a_place_optional" )}
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
                  {I18n.t( "views.users.edit.taxon_name_priorities.add_a_common_name_lexicon" )}
                </button>
              </div>
            </div>
          ) : (
            <div className="alert alert-warning text-center">
              { I18n.t( "views.users.edit.taxon_name_priorities.the_maximum_number_of_lexicons_have_been_added" ) }
            </div>
          )}
        </SettingsItem>
        { ( _.size( taxonNamePriorities ) > 0 ) && (
          <SettingsItem
            header={I18n.t( "views.users.edit.taxon_name_priorities.common_name_lexicon_display_order" )}
            htmlFor="taxon_name_priorities"
          >
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{
                __html: I18n.t( "views.users.edit.taxon_name_priorities.for_multiple_common_name_lexicons_drag_and_drop" )
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
