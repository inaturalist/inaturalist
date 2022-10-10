import React from "react";
import PropTypes from "prop-types";
import { Button } from "react-bootstrap";
import _ from "lodash";
import { objectToComparable } from "../../../shared/util";
import FiltersButton from "./filters_button";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PlaceAutocomplete from "./place_autocomplete";
import MarkAllAsReviewedButtonContainer from "../containers/mark_all_as_reviewed_button_container";
import ImageSizeControlButtonContainer from "../containers/image_size_control_button_container";

class SearchBar extends React.Component {
  shouldComponentUpdate( nextProps ) {
    const {
      params,
      defaultParams,
      allControlledTerms
    } = this.props;
    if (
      _.isEqual(
        objectToComparable( params ),
        objectToComparable( nextProps.params )
      )
      && _.isEqual(
        objectToComparable( defaultParams ),
        objectToComparable( nextProps.defaultParams )
      )
      && allControlledTerms === nextProps.allControlledTerms
    ) {
      // No change in underlying data series, don't update
      return false;
    }
    return true;
  }

  render( ) {
    const {
      params,
      defaultParams,
      updateSearchParams,
      replaceSearchParams,
      allControlledTerms,
      config
    } = this.props;
    return (
      <form className="SearchBar form-inline">
        <div className="pull-right">
          <ImageSizeControlButtonContainer />
          <MarkAllAsReviewedButtonContainer />
        </div>
        <span className="form-group">
          <TaxonAutocomplete
            bootstrapClear
            searchExternal={false}
            resetOnChange={false}
            initialTaxonID={params.taxon_id}
            afterSelect={result => {
              updateSearchParams( { taxon_id: result.item.id } );
            }}
            afterUnselect={idWas => {
              // Our autocompletes seem to fire afterUnselect for mysterious
              // reasons sometimes, even when the selected ID was null, leading to
              // annoying flickering effects and unnecessary requests. In theory
              // this shouldn't happen, but if it does, this should prevent
              // updating search params when there wasn't really a change.
              if ( idWas ) {
                updateSearchParams( { taxon_id: null } );
              }
            }}
          />
        </span>

        <span className="form-group">
          <PlaceAutocomplete
            config={config}
            resetOnChange={false}
            initialPlaceID={params.place_id}
            bootstrapClear
            afterSelect={result => {
              updateSearchParams( { place_id: result.item.id } );
            }}
            afterUnselect={idWas => {
              if ( idWas ) {
                updateSearchParams( { place_id: null } );
              }
            }}
          />
        </span>

        <Button bsStyle="primary">
          { I18n.t( "go" ) }
        </Button>
        { " " }
        <FiltersButton
          params={params}
          updateSearchParams={updateSearchParams}
          replaceSearchParams={replaceSearchParams}
          defaultParams={defaultParams}
          terms={allControlledTerms}
          config={config}
        />
        <div className="form-group">
          <div className="checkbox">
            <label>
              <input
                type="checkbox"
                checked={params.reviewed}
                onChange={function ( e ) {
                  updateSearchParams( { reviewed: e.target.checked } );
                }}
              />
              { I18n.t( "reviewed" ) }
            </label>
          </div>
        </div>
      </form>
    );
  }
}

SearchBar.propTypes = {
  params: PropTypes.object,
  defaultParams: PropTypes.object,
  updateSearchParams: PropTypes.func,
  replaceSearchParams: PropTypes.func,
  allControlledTerms: PropTypes.array,
  config: PropTypes.object
};

export default SearchBar;
