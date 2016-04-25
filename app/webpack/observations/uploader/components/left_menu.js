import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Button, Input, Glyphicon } from "react-bootstrap";
import TaxonAutocomplete from "../../identify/components/taxon_autocomplete";
import inaturalistjs from "inaturalistjs";
import DateTimeFieldWrapper from "./date_time_field_wrapper";

class LeftMenu extends Component {

  constructor( props, context ) {
    super( props, context );
    this.valuesOf = this.valuesOf.bind( this );
    this.commonValue = this.commonValue.bind( this );
    this.openLocationChooser = this.openLocationChooser.bind( this );
  }

  openLocationChooser( ) {
    let lat;
    let lng;
    let radius;
    let zoom;
    const commonLat = this.commonValue( "latitude" );
    const commonLng = this.commonValue( "longitude" );
    const commonRadius = this.commonValue( "accuracy" );
    const commonZoom = this.commonValue( "zoom" );
    if ( commonLat && commonLng && commonRadius ) {
      lat = commonLat;
      lng = commonLng;
      radius = commonRadius;
      zoom = commonZoom;
    }
    this.props.setState( { locationChooser: {
      show: true,
      zoom,
      radius,
      lat,
      lng,
      notes: this.commonValue( "locality_notes" ),
      geoprivacy: this.commonValue( "geoprivacy" )
    } } );
  }

  valuesOf( attr ) {
    return _.uniqBy( _.map( this.props.selectedObsCards, c => c[attr] ),
      a => a && ( a.id || a ) );
  }

  commonValue( attr ) {
    const uniq = this.valuesOf( attr );
    return ( uniq.length === 1 ) ? uniq[0] : undefined;
  }

  render( ) {
    const { updateSelectedObsCards, selectedObsCards } = this.props;
    const keys = _.keys( selectedObsCards );
    const count = keys.length;
    const uniqDescriptions = this.valuesOf( "description" );
    const commonDescription = this.commonValue( "description" );
    const commonSpeciesGuess = this.commonValue( "species_guess" );
    const commonSelectedTaxon = this.commonValue( "selected_taxon" );
    const commonDate = this.commonValue( "date" );
    const commonLat = this.commonValue( "latitude" );
    const commonLng = this.commonValue( "longitude" );
    const commonNotes = this.commonValue( "locality_notes" );
    let descriptionPlaceholder = "Enter description";
    if ( uniqDescriptions.length > 1 ) {
      descriptionPlaceholder = "Edit multiple descriptions";
    }
    let globe = (
      <Button onClick={ this.openLocationChooser }>
        <Glyphicon glyph="globe" />
      </Button>
    );
    let menu;
    let locationText = commonNotes ||
      ( commonLat && commonLng &&
      `${_.round( commonLat, 4 )},${_.round( commonLng, 4 )}` );
    if ( count === 0 ) {
      menu = <h4 className="empty">Select observations to edit...</h4>;
    } else {
      menu = (
        <div>
          <h4>Editing {count} observation{count > 1 ? "s" : ""}</h4>
          <TaxonAutocomplete
            key={ `multitaxonac${commonSelectedTaxon && commonSelectedTaxon.id}` }
            bootstrapClear
            searchExternal
            showPlaceholder
            allowPlaceholders
            perPage={ 6 }
            value={ ( commonSelectedTaxon && commonSelectedTaxon.id ) ?
              commonSelectedTaxon.title : commonSpeciesGuess }
            initialSelection={ commonSelectedTaxon }
            afterSelect={ function ( result ) {
              updateSelectedObsCards( {
                taxon_id: result.item.id,
                selected_taxon: new inaturalistjs.Taxon( result.item ) } );
            } }
            afterUnselect={ ( ) => {
              updateSelectedObsCards( {
                taxon_id: undefined,
                selected_taxon: undefined } );
            } }
            onChange={ e => updateSelectedObsCards( {
              species_guess: e.target.value, selected_species_guess: e.target.value
            } ) }
          />
          <DateTimeFieldWrapper
            defaultText={ commonDate }
            onChange={ dateString => updateSelectedObsCards(
              { date: dateString, selected_date: dateString } ) }
          />
          <Input type="text" buttonAfter={ globe } readOnly
            value={ locationText } onClick={ this.openLocationChooser }
          />
          <Input type="textarea"
            placeholder={ descriptionPlaceholder } value={ commonDescription }
            onChange={ e => updateSelectedObsCards( { description: e.target.value } ) }
          />
          <Input type="checkbox"
            label="Captive or cultivated"
            checked={ this.commonValue( "captive" ) }
            value="true"
            onChange={ e => updateSelectedObsCards( { captive: $( e.target ).is( ":checked" ) } ) }
          />
        </div>
      );
    }
    return (
      <div id="multiMenu">
        {menu}
      </div>
    );
  }
}

LeftMenu.propTypes = {
  obsCards: PropTypes.object,
  selectedObsCards: PropTypes.object,
  updateSelectedObsCards: PropTypes.func,
  setState: PropTypes.func
};

export default LeftMenu;
