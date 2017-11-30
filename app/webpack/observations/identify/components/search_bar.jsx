import React, { PropTypes } from "react";
import { Input, Button } from "react-bootstrap";
import _ from "lodash";
import { objectToComparable } from "../../../shared/util";
import FiltersButton from "./filters_button";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PlaceAutocomplete from "./place_autocomplete";

class SearchBar extends React.Component {
  shouldComponentUpdate( nextProps ) {
    if (
      _.isEqual(
        objectToComparable( this.props.params ),
        objectToComparable( nextProps.params )
      )
      &&
      _.isEqual(
        objectToComparable( this.props.defaultParams ),
        objectToComparable( nextProps.defaultParams )
      )
      &&
      this.props.allReviewed === nextProps.allReviewed
      &&
      this.props.allControlledTerms === nextProps.allControlledTerms
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
      reviewAll,
      unreviewAll,
      allReviewed,
      allControlledTerms
    } = this.props;
    return (
      <form className="SearchBar form-inline">
        <TaxonAutocomplete
          bootstrapClear
          searchExternal={false}
          resetOnChange={false}
          initialTaxonID={params.taxon_id}
          afterSelect={ function ( result ) {
            updateSearchParams( { taxon_id: result.item.id } );
          } }
          afterUnselect={ idWas => {
            // Our autocompletes seem to fire afterUnselect for mysterious
            // reasons sometimes, even when the selected ID was null, leading to
            // annoying flickering effects and unnecessary requests. In theory
            // this shouldn't happen, but if it does, this should prevent
            // updating search params when there wasn't really a change.
            if ( idWas ) {
              updateSearchParams( { taxon_id: null } );
            }
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
            afterUnselect={ idWas => {
              if ( idWas ) {
                updateSearchParams( { place_id: null } );
              }
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
          terms={allControlledTerms}
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
  }
}


SearchBar.propTypes = {
  params: PropTypes.object,
  defaultParams: PropTypes.object,
  updateSearchParams: PropTypes.func,
  replaceSearchParams: PropTypes.func,
  reviewAll: PropTypes.func,
  unreviewAll: PropTypes.func,
  allReviewed: PropTypes.bool,
  allControlledTerms: PropTypes.array
};

export default SearchBar;
