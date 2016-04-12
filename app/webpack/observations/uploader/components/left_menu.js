import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Button, Input, Glyphicon } from "react-bootstrap";
import TaxonAutocomplete from "../../identify/components/taxon_autocomplete";
import { DateTimePicker } from "react-widgets";
import inaturalistjs from "inaturalistjs";

class LeftMenu extends Component {

  constructor( props, context ) {
    super( props, context );
    this.valuesOf = this.valuesOf.bind( this );
    this.commonValue = this.commonValue.bind( this );
    this.openLocationChooser = this.openLocationChooser.bind( this );
  }

  openLocationChooser( ) {
    let center;
    let radius;
    let zoom;
    const commonLat = this.commonValue( "latitude" );
    const commonLng = this.commonValue( "longitude" );
    const commonRadius = this.commonValue( "accuracy" );
    const commonZoom = this.commonValue( "zoom" );
    if ( commonLat && commonLng && commonRadius ) {
      center = { lat: commonLat, lng: commonLng };
      radius = commonRadius;
      zoom = commonZoom;
    }
    this.props.setState( { locationChooser: {
      open: true,
      zoom,
      radius,
      center
    } } );
  }

  valuesOf( attr ) {
    return _.chain( this.props.selectedObsCards ).map( attr ).uniq( ).value( );
  }

  commonValue( attr ) {
    const uniq = this.valuesOf( attr );
    return ( uniq.length === 1 ) ? uniq[0] : undefined;
  }

  render( ) {
    const { updateSelectedObsCards, selectedObsCards } = this.props;
    const count = _.keys( selectedObsCards ).length;
    const uniqDescriptions = this.valuesOf( "description" );
    const commonDescription = this.commonValue( "description" );
    const commonSelectedTaxon = this.commonValue( "selected_taxon" );
    const commonDate = this.commonValue( "date" );
    const commonLat = this.commonValue( "latitude" );
    const commonLng = this.commonValue( "longitude" );
    let descriptionPlaceholder = "Enter description";
    if ( uniqDescriptions.length > 1 ) {
      descriptionPlaceholder = "Edit multiple descriptions";
    }
    let globe = (
      <Button onClick={ this.openLocationChooser }>
        <Glyphicon glyph="globe" />
      </Button>
    );
    return (
      <div id="multiMenu" key={ `multiMenu:${count}` }>
        <TaxonAutocomplete
          bootstrapClear
          searchExternal={false}
          initialSelection={ commonSelectedTaxon }
          afterSelect={ function ( result ) {
            updateSelectedObsCards( { taxon_id: result.item.id,
              selected_taxon: new inaturalistjs.Taxon( result.item ) } );
          } }
          afterUnselect={ ( ) => {
            updateSelectedObsCards( { taxon_id: undefined, selected_taxon: undefined } );
          } }
        />
        <DateTimePicker key={ `datetime:${count}` }key={ commonDate } defaultValue={ commonDate }
          onChange={ e => updateSelectedObsCards( { date: e } ) }
        />
        <Input key={ `location:${count}` }type="text" buttonAfter={ globe } value={
          commonLat && commonLng &&
            `${_.round( commonLat, 4 )},${_.round( commonLng, 4 )}` }
        />
        <Input key={ `description:${count}` } type="textarea"
          placeholder={ descriptionPlaceholder } value={ commonDescription }
          onChange={ e => updateSelectedObsCards( { description: e.target.value } ) }
        />
      </div>
    );
  }
}

LeftMenu.propTypes = {
  selectedObsCards: PropTypes.object,
  updateSelectedObsCards: PropTypes.func,
  setState: PropTypes.func
};

export default LeftMenu;
