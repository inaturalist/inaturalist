import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Input, Glyphicon, Badge } from "react-bootstrap";
import TaxonAutocomplete from "./taxon_autocomplete";
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
    let descriptionPlaceholder = I18n.t( "description" );
    if ( uniqDescriptions.length > 1 ) {
      descriptionPlaceholder = I18n.t( "edit_multiple_descriptions" );
    }
    let locationText = commonNotes ||
      ( commonLat && commonLng &&
      `${_.round( commonLat, 4 )},${_.round( commonLng, 4 )}` );
    const commonTags = this.commonValue( "tags" );
    let taglist;
    if ( commonTags && commonTags.length > 0 ) {
      taglist = (
        <div className="tags">
          { I18n.t( "tags" ) }
          <div className="taglist">
            { _.map( commonTags, t => (
              <Badge className="tag" key={ t }>{ t }</Badge>
            ) ) }
          </div>
        </div>
      );
    }
    let ofvlist;
    const commonOfvs = this.commonValue( "observation_field_values" );
    if ( commonOfvs && commonOfvs.length > 0 ) {
      ofvlist = (
        <div className="tags">
          { I18n.t( "custom_field_values" ) }
          <div className="taglist">
            { _.map( commonOfvs, t => {
              const key = `${t.observation_field.name}` +
                `${( t.taxon && t.taxon.name ) ? t.taxon.name : t.value}`;
              return ( <Badge className="tag" key={ key }>
                <span className="field">{ `${t.observation_field.name}:` }</span>
                { `${( t.taxon && t.taxon.name ) ? t.taxon.name : t.value}` }
              </Badge> );
            } ) }
          </div>
        </div>
      );
    }
    let menu;
    if ( count === 0 ) {
      menu = I18n.t( "select_observations_to_edit" );
    } else {
      let text = I18n.t( "editing_observations", { count } );
      menu = (
        <div>
          { text }
          <br />
          <br />
          <TaxonAutocomplete
            key={
              `multitaxonac${commonSelectedTaxon && commonSelectedTaxon.id}` }
            bootstrap
            searchExternal
            showPlaceholder
            perPage={ 6 }
            initialSelection={ commonSelectedTaxon }
          />
          <DateTimeFieldWrapper
            ref="datetime"
            defaultText={ commonDate }
            onChange={ dateString => updateSelectedObsCards(
              { date: dateString, selected_date: dateString } ) }
          />
          <div className="input-group">
            <div className="input-group-addon">
              <Glyphicon glyph="calendar" />
            </div>
            <input
              type="text"
              onClick= { () => {
                if ( this.refs.datetime ) {
                  this.refs.datetime.onClick( );
                }
              } }
              className="form-control"
              value={ commonDate }
              onChange= { e => {
                if ( this.refs.datetime ) {
                  this.refs.datetime.onChange( undefined, e.target.value );
                }
              } }
              placeholder={ I18n.t( "date_" ) }
            />
          </div>
          <div className="input-group"
            onClick={ this.openLocationChooser }
          >
            <div className="input-group-addon">
              <Glyphicon glyph="map-marker" />
            </div>
            <input
              type="text"
              className="form-control"
              value={ locationText }
              placeholder={ I18n.t( "location" ) }
              readOnly
            />
          </div>
          <div className="form-group">
            <textarea
              placeholder={ descriptionPlaceholder }
              className="form-control"
              value={ commonDescription }
              onChange={ e => updateSelectedObsCards( { description: e.target.value } ) }
            />
          </div>
          <Input type="checkbox"
            label={ I18n.t( "captive_cultivated" ) }
            checked={ this.commonValue( "captive" ) }
            value="true"
            onChange={ e => updateSelectedObsCards( { captive: $( e.target ).is( ":checked" ) } ) }
          />
          { taglist }
          { ofvlist }
        </div>
      );
    }
    return (
      <div className="left-col-padding">
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
