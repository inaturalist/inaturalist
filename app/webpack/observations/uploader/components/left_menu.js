import _ from "lodash";
import moment from "moment-timezone";
import React, { PropTypes } from "react";
import { Input, Glyphicon, Badge, Accordion, Panel } from "react-bootstrap";
import TaxonAutocomplete from "./taxon_autocomplete";
import DateTimeFieldWrapper from "./date_time_field_wrapper";
import SelectionBasedComponent from "./selection_based_component";

class LeftMenu extends SelectionBasedComponent {

  constructor( props, context ) {
    super( props, context );
    this.removeTag = this.removeTag.bind( this );
    this.submitTag = this.submitTag.bind( this );
    this.commonValue = this.commonValue.bind( this );
    this.openLocationChooser = this.openLocationChooser.bind( this );
  }

  shouldComponentUpdate( nextProps ) {
    if ( this.props.reactKey === nextProps.reactKey ) { return false; }
    return true;
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
      geoprivacy: this.commonValue( "geoprivacy" ),
      obsCards: this.props.selectedObsCards
    } } );
  }

  submitTag( e ) {
    e.preventDefault( );
    const input = $( e.target ).find( "input" );
    const tag = _.trim( input.val( ) );
    if ( tag ) {
      this.props.appendToSelectedObsCards( { tags: tag } );
    }
    input.val( "" );
  }

  removeTag( t ) {
    this.props.removeFromSelectedObsCards( { tags: t } );
  }

  render( ) {
    const { updateSelectedObsCards, selectedObsCards } = this.props;
    const keys = _.keys( selectedObsCards );
    const count = keys.length;
    const uniqDescriptions = this.valuesOf( "description" );
    const commonDescription = this.commonValue( "description" );
    const commonSelectedTaxon = this.commonValue( "selected_taxon" );
    const commonDate = this.commonValue( "date" );
    const commonLat = this.commonValue( "latitude" );
    const commonLng = this.commonValue( "longitude" );
    const commonNotes = this.commonValue( "locality_notes" );
    const commonGeoprivacy = this.commonValue( "geoprivacy" );
    let locationText = commonNotes ||
      ( commonLat && commonLng &&
      `${_.round( commonLat, 4 )},${_.round( commonLng, 4 )}` );
    const commonTags = _.uniq( _.flatten( this.valuesOf( "tags" ) ) );
    const commonOfvs = this.commonValue( "observation_field_values" );
    let multipleGeoprivacy = !commonGeoprivacy && ( <option>{ " -- multiple -- " }</option> );
    let taglist = (
      <Accordion>
        <Panel
          eventKey="1"
          className="tags-panel"
          header={ ( <div>Tags<Glyphicon glyph="menu-right" /></div> ) }
          onEnter={ () => { $( ".tags-panel .glyphicon" ).addClass( "rotate" ); } }
          onExit={ () => { $( ".tags-panel .glyphicon" ).removeClass( "rotate" ); } }
        >
          <div className="tags">
            <form onSubmit={this.submitTag}>
              <div className="input-group">
                <input
                  type="text"
                  className="form-control input-sm"
                  placeholder="Add a tag..."
                  ref="input-tag"
                  onKeyPress={ this.checkTagSubmit }
                />
                <span className="input-group-btn">
                  <button
                    className="btn btn-default btn-sm"
                    type="submit"
                  >
                    Add
                  </button>
                </span>
              </div>
            </form>
            <div className="taglist">
              { _.map( commonTags, t => (
                <Badge className="tag" key={ t }>
                  { t }
                  <Glyphicon glyph="remove-circle" onClick={ () => {
                    this.removeTag( t );
                  } }
                  />
                </Badge>
              ) ) }
            </div>
          </div>
        </Panel>
      </Accordion>
    );
    let ofvlist = (
      <Accordion>
        <Panel
          eventKey="1"
          className="ofvs-panel"
          header={ ( <div>Custom Fields<Glyphicon glyph="menu-right" /></div> ) }
          onEnter={ () => { $( ".ofvs-panel .glyphicon" ).addClass( "rotate" ); } }
          onExit={ () => { $( ".ofvs-panel .glyphicon" ).removeClass( "rotate" ); } }
        >
          <div className="tags">
            <form onSubmit={this.submitTag}>
              <div className="input-group">
                <input
                  type="text"
                  className="form-control input-sm ofv-field"
                  placeholder="Field"
                  ref="input-tag"
                />
                <input
                  type="text"
                  className="form-control input-sm ofv-value"
                  placeholder="Value"
                  ref="input-tag"
                />
                <span className="input-group-btn">
                  <button
                    className="btn btn-default btn-sm"
                    type="submit"
                  >
                    Add
                  </button>
                </span>
              </div>
            </form>
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
        </Panel>
      </Accordion>
    );
    let menu;
    if ( count === 0 ) {
      menu = ( <span className="head">{ I18n.t( "select_observations_to_edit" )} </span> );
    } else {
      menu = (
        <div>
          <span className="head" dangerouslySetInnerHTML={
            { __html: I18n.t( "editing_observations", { count } ) } }
          />
          <br />
          <br />
          <TaxonAutocomplete
            key={
              `multitaxonac${commonSelectedTaxon && commonSelectedTaxon.title}` }
            bootstrap
            searchExternal
            showPlaceholder
            perPage={ 6 }
            initialSelection={ commonSelectedTaxon }
            afterSelect={ r => {
              if ( !commonSelectedTaxon || r.item.id !== commonSelectedTaxon.id ) {
                updateSelectedObsCards(
                  { taxon_id: r.item.id,
                    selected_taxon: r.item,
                    species_guess: r.item.title } );
              }
            } }
            afterUnselect={ ( ) => {
              if ( commonSelectedTaxon ) {
                updateSelectedObsCards(
                  { taxon_id: null,
                    selected_taxon: null,
                    species_guess: null } );
              }
            } }
            placeholder={ this.valuesOf( "selected_taxon" ).length > 1 ?
              I18n.t( "edit_multiple_species" ) : I18n.t( "species_name_cap" ) }
          />
          <DateTimeFieldWrapper
            ref="datetime"
            key={ `multidate${commonDate}` }
            reactKey={ `multidate${commonDate}` }
            dateTime={ commonDate ?
                moment( commonDate, "YYYY/MM/DD h:mm A z" ).format( "x" ) : undefined }
            onChange={ dateString => updateSelectedObsCards(
              { date: dateString, selected_date: dateString } ) }
          />
          <div className="input-group"
            onClick= { ( ) => {
              if ( this.refs.datetime ) {
                this.refs.datetime.onClick( );
              }
            } }
          >
            <div className="input-group-addon">
              <Glyphicon glyph="calendar" />
            </div>
            <input
              type="text"
              className="form-control"
              value={ commonDate }
              onChange= { e => {
                if ( this.refs.datetime ) {
                  this.refs.datetime.onChange( undefined, e.target.value );
                }
              } }
              placeholder={ this.valuesOf( "date" ).length > 1 ?
                I18n.t( "edit_multiple_dates" ) : I18n.t( "date_" ) }
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
              placeholder={ ( this.valuesOf( "latitude" ).length > 1 &&
                this.valuesOf( "longitude" ).length > 1 ) ?
                I18n.t( "edit_multiple_locations" ) : I18n.t( "location" ) }
              readOnly
            />
          </div>
          <div className="form-group">
            <textarea
              placeholder={ uniqDescriptions.length > 1 ?
                I18n.t( "edit_multiple_descriptions" ) : I18n.t( "description" ) }
              className="form-control"
              value={ commonDescription || "" }
              onChange={ e => updateSelectedObsCards( { description: e.target.value } ) }
            />
          </div>
          <Accordion>
            <Panel
              eventKey="1"
              className="details-panel"
              header={ ( <div>More<Glyphicon glyph="menu-right" /></div> ) }
              onEnter={ () => { $( ".details-panel .glyphicon" ).addClass( "rotate" ); } }
              onExit={ () => { $( ".details-panel .glyphicon" ).removeClass( "rotate" ); } }
            >
              <Input
                key={ `multigeoprivacy${commonGeoprivacy}` }
                type="select"
                label={ I18n.t( "geoprivacy" ) }
                value={ commonGeoprivacy }
                onChange={ e => updateSelectedObsCards( { geoprivacy: e.target.value } ) }
              >
                { multipleGeoprivacy }
                <option value="open">{ I18n.t( "open" ) }</option>
                <option value="obscured">{ I18n.t( "obscured_" ) }</option>
                <option value="private">{ I18n.t( "private" ) }</option>
              </Input>
              <Input type="checkbox"
                label={ I18n.t( "captive_cultivated" ) }
                checked={ this.commonValue( "captive" ) }
                value="true"
                onChange={ e => updateSelectedObsCards( { captive: $( e.target ).is( ":checked" ) } ) }
              />
            </Panel>
          </Accordion>
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
  appendToSelectedObsCards: PropTypes.func,
  removeFromSelectedObsCards: PropTypes.func,
  setState: PropTypes.func,
  reactKey: PropTypes.string
};

export default LeftMenu;
