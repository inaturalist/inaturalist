import _ from "lodash";
import moment from "moment-timezone";
import React, { PropTypes } from "react";
import { Input, Glyphicon, Accordion, Panel, Badge,
  OverlayTrigger, Tooltip } from "react-bootstrap";
import TaxonAutocomplete from "./taxon_autocomplete";
import DateTimeFieldWrapper from "./date_time_field_wrapper";
import SelectionBasedComponent from "./selection_based_component";
import ObservationFieldsChooser from "./observation_fields_chooser";
import ProjectsChooser from "./projects_chooser";
import TagsChooser from "./tags_chooser";

class LeftMenu extends SelectionBasedComponent {

  constructor( props, context ) {
    super( props, context );
    this.details = this.details.bind( this );
    this.formPanel = this.formPanel.bind( this );
    this.openLocationChooser = this.openLocationChooser.bind( this );
  }

  shouldComponentUpdate( nextProps ) {
    if ( this.props.reactKey === nextProps.reactKey ) { return false; }
    return true;
  }

  openLocationChooser( ) {
    this.props.setState( { locationChooser: {
      show: true,
      zoom: this.commonValue( "zoom" ),
      radius: this.commonValue( "accuracy" ),
      lat: this.commonValue( "latitude" ),
      lng: this.commonValue( "longitude" ),
      notes: this.commonValue( "locality_notes" ),
      geoprivacy: this.commonValue( "geoprivacy" ),
      obsCards: this.props.selectedObsCards
    } } );
  }

  details( ) {
    const { updateSelectedObsCards } = this.props;
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
    let multipleGeoprivacy = !commonGeoprivacy && ( <option>{ " -- multiple -- " }</option> );
    let geoprivacyTooltip = "Everyone can see the coordinates unless the taxon is threatened";
    if ( commonGeoprivacy === "obscured" ) {
      geoprivacyTooltip = "Public coordinates shown as a random point within a 0.2 by 0.2 degree area that contains the true coordinates, which works out to about a 22x22 km square area of uncertainty at the equator, decreasing as you approach the poles. True coordinates are only visible to you and the curators of projects to which you add the observation";
    } else if ( commonGeoprivacy === "obscured" ) {
      geoprivacyTooltip = "Coordinates completely hidden from public maps, true coordinates only visible to you and the curators of projects to which you add the observation";
    }
    return (
      <div>
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
        <OverlayTrigger
          placement="top"
          delayShow={ 1000 }
          overlay={ ( <Tooltip id="left-date-tip">Date and time of observation</Tooltip> ) }
        >
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
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={ 1000 }
          overlay={ ( <Tooltip id="left-date-tip">Location of observation</Tooltip> ) }
        >
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
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={ 1000 }
          overlay={ ( <Tooltip id="left-date-tip">Description</Tooltip> ) }
        >
          <div className="form-group">
            <textarea
              placeholder={ uniqDescriptions.length > 1 ?
                I18n.t( "edit_multiple_descriptions" ) : I18n.t( "description" ) }
              className="form-control"
              value={ commonDescription || "" }
              onChange={ e => updateSelectedObsCards( { description: e.target.value } ) }
            />
          </div>
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={ 1000 }
          overlay={ multipleGeoprivacy ? ( <span /> ) :
            ( <Tooltip id="left-date-tip">{ geoprivacyTooltip }</Tooltip> ) }
        >
          <Input
            key={ `multigeoprivacy${commonGeoprivacy}` }
            type="select"
            value={ commonGeoprivacy }
            onChange={ e => updateSelectedObsCards( { geoprivacy: e.target.value } ) }
          >
            { multipleGeoprivacy }
            <option value="open">{ "Location is public" }</option>
            <option value="obscured">{ "Location is obscured" }</option>
            <option value="private">{ "Location is private" }</option>
          </Input>
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={ 1000 }
          overlay={ ( <Tooltip id="left-date-tip">The organism exists where it was observed because humans intended it to be there. iNaturalist is about observing wild organism, and our scientific data partners are not interested in observations of pets, gardens, or animals in zoos</Tooltip> ) }
        >
          <div className="form-group">
            <div className="checkbox">
              <label>
                <input type="checkbox"
                  checked={ this.commonValue( "captive" ) }
                  value="true"
                  onChange={ e =>
                    updateSelectedObsCards( { captive: $( e.target ).is( ":checked" ) } ) }
                />
                <span>{ I18n.t( "captive_cultivated" ) }</span>
              </label>
            </div>
          </div>
        </OverlayTrigger>
      </div>
    );
  }

  formPanel( key, title, glyph, contents, contentCount, open ) {
    let openGlyphClass = "toggle";
    if ( open ) { openGlyphClass += " rotate"; }
    let badge = contentCount && contentCount > 0 ? (
      <Badge className="count">{ contentCount }</Badge>
    ) : undefined;
    let header = (
      <div className={ contentCount && "contents" }>
        <Glyphicon glyph={ glyph } className="icon" />
        { title }
        <Glyphicon glyph="triangle-right" className={ openGlyphClass } />
        { badge }
      </div>
    );
    let className = `panel-${key}`;
    const entered = ( key !== "1" ) ? () => {
      if ( !$( ".observation-field" ).is( ":visible" ) ) {
        const mainPanelInput = $( `.${className} input:first` );
        mainPanelInput.focus( ).select( ).val( mainPanelInput.val( ) );
      }
    } : undefined;
    return (
      <Panel
        eventKey={ key }
        className={ className }
        header={ header }
        onEnter={ () => { $( `.${className} .toggle` ).addClass( "rotate" ); } }
        onEntered={ () => setTimeout( entered, 50 ) }
        onExit={ () => { $( `.${className} .toggle` ).removeClass( "rotate" ); } }
      >
        { contents }
      </Panel>
    );
  }

  render( ) {
    const count = _.keys( this.props.selectedObsCards ).length;
    let menu;
    const detailsContent =
      this.uniqueValuesOf( "description" ).length > 0 ||
      this.uniqueValuesOf( "date" ).length > 0 ||
      this.uniqueValuesOf( "latitude" ).length > 0 ||
      this.uniqueValuesOf( "longitude" ).length > 0 ||
      this.uniqueValuesOf( "locality_notes" ).length > 0 ||
      this.uniqueValuesOf( "species_guess" ).length > 0 ||
      this.uniqueValuesOf( "selected_taxon" ).length > 0;
    const tagsContent = this.uniqueValuesOf( "tags" ).length;
    const projectsContent = this.uniqueValuesOf( "projects" ).length;
    const fieldsContent = this.uniqueValuesOf( "observation_field_values" ).length;
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
          <Accordion defaultActiveKey="1">
            { this.formPanel( "1", "Details", "pencil",
              this.details( ), detailsContent, true ) }
            { this.formPanel( "2", "Tags", "tag", (
              <TagsChooser { ...this.props } /> ), tagsContent ) }
            { this.formPanel( "3", "Projects", "briefcase", (
              <ProjectsChooser { ...this.props } /> ), projectsContent ) }
            { this.formPanel( "4", "Fields", "th-list", (
              <ObservationFieldsChooser { ...this.props } /> ), fieldsContent ) }
          </Accordion>
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
