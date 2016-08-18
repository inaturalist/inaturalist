import React, { PropTypes } from "react";
import { Input, Button } from "react-bootstrap";
import FiltersButton from "./filters_button";
import TaxonAutocomplete from "./taxon_autocomplete";
import PlaceAutocomplete from "./place_autocomplete";

const SearchBar = ( {
  params,
  defaultParams,
  updateSearchParams,
  replaceSearchParams,
  reviewAll,
  unreviewAll,
  allReviewed
} ) => (
  <form className="SearchBar form-inline">
    <TaxonAutocomplete
      bootstrapClear
      searchExternal={false}
      resetOnChange={false}
      initialTaxonID={params.taxon_id}
      afterSelect={ function ( result ) {
        updateSearchParams( { taxon_id: result.item.id } );
      } }
      afterUnselect={ function ( ) {
        updateSearchParams( { taxon_id: null } );
      } }
    />
    <span className="form-group">
      <PlaceAutocomplete
        resetOnChange={false}
        initialPlaceID={
          parseInt( params.place_id, { precision: 0 } ) > 0 ? params.place_id : null
        }
        bootstrapClear
        afterSelect={ function ( result ) {
          updateSearchParams( { place_id: result.item.id } );
        } }
        afterUnselect={ function ( ) {
          updateSearchParams( { place_id: null } );
        } }
      />
    </span>
    <Button bsStyle="primary">
      { I18n.t( "go" ) }
    </Button> <FiltersButton
      params={params}
      updateSearchParams={updateSearchParams}
      replaceSearchParams={replaceSearchParams}
      defaultParams={defaultParams}
    />
    <Input
      type="checkbox"
      label={ I18n.t( "reviewed" ) }
      checked={ params.reviewed }
      onChange={function ( e ) {
        updateSearchParams( { reviewed: e.target.checked } );
      }}
    />
    <div className="pull-right">
      <Button
        bsStyle={allReviewed ? "primary" : "default"}
        onClick={ ( ) => ( allReviewed ? unreviewAll( ) : reviewAll( ) ) }
      >
        <i
          className={`fa fa-eye${allReviewed ? "-slash" : ""}`}
        ></i> {
          allReviewed ? I18n.t( "mark_all_as_unreviewed" ) : I18n.t( "mark_all_as_reviewed" )
        }
      </Button>
    </div>
  </form>
);


SearchBar.propTypes = {
  params: PropTypes.object,
  defaultParams: PropTypes.object,
  updateSearchParams: PropTypes.func,
  replaceSearchParams: PropTypes.func,
  reviewAll: PropTypes.func,
  unreviewAll: PropTypes.func,
  allReviewed: PropTypes.bool
};

export default SearchBar;
