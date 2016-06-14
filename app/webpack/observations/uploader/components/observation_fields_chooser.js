import _ from "lodash";
import moment from "moment-timezone";
import React, { PropTypes } from "react";
import { Input, Glyphicon, Badge, OverlayTrigger, Tooltip, Button } from "react-bootstrap";
import TaxonAutocomplete from "./taxon_autocomplete";
import DateTimeFieldWrapper from "./date_time_field_wrapper";
import SelectionBasedComponent from "./selection_based_component";

class LeftMenu extends SelectionBasedComponent {

  constructor( props, context ) {
    super( props, context );
    this.submitFieldValue = this.submitFieldValue.bind( this );
    this.removeFieldValue = this.removeFieldValue.bind( this );
    this.setUpObservationFieldAutocomplete = this.setUpObservationFieldAutocomplete.bind( this );
  }

  componentDidMount( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  componentDidUpdate( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  setUpObservationFieldAutocomplete( ) {
    const input = $( ".ofvs input.ofv-field" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.autocomplete( "destroy" );
      input.removeData( "uiAutocomplete" );
    }
    input.observationFieldAutocomplete( {
      resetOnChange: false,
      allowEnterSubmit: false,
      idEl: $( "<input/>" ),
      appendTo: $( ".leftColumn" ),
      afterSelect: p => {
        if ( p ) {
          this.props.setState( {
            observationField: p.item,
            observationFieldValue: null,
            observationFieldSelectedDate: null
          } );
          setTimeout( () => {
            $( ".observation-field [name='value'], .observation-field [name='taxon_name']" ).
              focus( ).select( ).trigger( "click" );
          }, 100 );
        }
        input.val( "" );
      }
    } );
  }

  submitFieldValue( e ) {
    e.preventDefault( );
    const observationFieldID = $( e.target ).find( "input[name='observation_field_id']" );
    const value = $( e.target ).find( "[name='value']" );
    if ( this.props.observationField && this.props.observationFieldValue ) {
      this.props.appendToSelectedObsCards( { observation_field_values:
        { observation_field_id: this.props.observationField.id,
          value: this.props.observationFieldValue,
          taxon: this.props.observationFieldTaxon,
          observation_field: this.props.observationField }
      } );
      this.props.setState( {
        observationField: null,
        observationFieldValue: null,
        observationFieldTaxon: null
      } );
    } else if ( observationFieldID && value ) {
      this.props.appendToSelectedObsCards( { observation_field_values:
        { observation_field_id: observationFieldID.val( ),
          value: value.val( ),
          // taxon
          observation_field: this.props.observationField }
      } );
      this.props.setState( {
        observationField: null,
        observationFieldValue: null,
        observationFieldTaxon: null
      } );
    }
    observationFieldID.val( "" );
    value.val( "" );
    $( ".ofvs input.ofv-field" ).focus( ).select( ).val( "" );
  }

  removeFieldValue( ofv ) {
    this.props.removeFromSelectedObsCards( { observation_field_values: ofv } );
  }

  render( ) {
    const commonOfvs = this.commonValue( "observation_field_values" );
    let observationFieldInput;
    const field = this.props.observationField;
    if ( field ) {
      let input;
      let submit;
      if ( field.allowed_values ) {
        input = (
          <Input type="select" name="value" >
            { _.map( field.allowed_values.split( "|" ), f => (
              <option value={ f } key={ f }>{ f }</option>
            ) ) }
          </Input>
        );
        submit = ( <Button className="standalone" type="submit">Add</Button> );
      } else if ( field.datatype === "taxon" ) {
        input = (
          <div className="input-group">
            <TaxonAutocomplete
              bootstrap
              searchExternal
              showPlaceholder={ false }
              perPage={ 6 }
              afterSelect={ r => {
                this.props.setState( {
                  observationFieldTaxon: r.item,
                  observationFieldValue: r.item.id } );
              } }
              afterUnselect={ ( ) => {
                this.props.setState( {
                  observationFieldTaxon: null,
                  observationFieldValue: null } );
              } }
              placeholder={ I18n.t( "species_name_cap" ) }
            />
            <span className="input-group-btn">
              <button
                className="btn btn-default"
                type="submit"
              >
                Add
              </button>
            </span>
          </div>
        );
      } else if ( field.datatype === "datetime" ||
                  field.datatype === "time" ||
                  field.datatype === "date" ) {
        /* global TIMEZONE */
        let mode;
        if ( field.datatype === "time" ) { mode = "time"; }
        else if ( field.datatype === "date" ) { mode = "date"; }
        let format = "YYYY/MM/DD h:mm A z";
        if ( field.datatype === "time" ) { format = "HH:mm"; }
        else if ( field.datatype === "date" ) { format = "YYYY/MM/DD"; }
        input = (
          <div className="input-group">
            <DateTimeFieldWrapper
              key={ `datetime${this.props.observationFieldSelectedDate}`}
              reactKey={ `datetime${this.props.observationFieldSelectedDate}`}
              ref="datetime"
              mode={ mode }
              inputFormat={ format }
              dateTime={ this.props.observationFieldDateTime ?
                moment( this.props.observationFieldDateTime, format ).format( "x" )
                : undefined }
              timeZone={ TIMEZONE }
              onChange={ dateString =>
                this.props.setState( { observationFieldValue: dateString } ) }
              onSelection={ dateString =>
                this.props.setState( { observationFieldValue: dateString,
                  observationFieldSelectedDate: dateString } )
              }
            />
            <input
              type="text"
              name="value"
              className="form-control"
              autoComplete="off"
              value={ this.props.observationFieldValue }
              onClick= { () => {
                if ( this.refs.datetime ) {
                  this.refs.datetime.onClick( );
                }
              } }
              onChange= { e => {
                if ( this.refs.datetime ) {
                  this.refs.datetime.onChange( undefined, e.target.value );
                }
              } }
              placeholder={ I18n.t( "date_" ) }
            />
            <span className="input-group-btn">
              <button
                className="btn btn-default"
                type="submit"
              >
                Add
              </button>
            </span>
          </div>
        );
      } else {
        input = (
          <div className="input-group">
            <input
              type="text"
              name="value"
              className="form-control"
            />
            <span className="input-group-btn">
              <button
                className="btn btn-default"
                type="submit"
              >
                Add
              </button>
            </span>
          </div>
        );
      }
      observationFieldInput = (
        <div className="observation-field">
          <h4>{ field.name }</h4>
          { input }
          <p className="help-block">{ field.description }</p>
          { submit }
        </div>
      );
    }
    return (
      <div className="ofvs">
        <form onSubmit={ this.submitFieldValue }>
          <div className="input-group">
            <div className="input-group-addon input-sm">
              <Glyphicon glyph="th-list" />
            </div>
            <input
              type="text"
              className="form-control ofv-field"
              placeholder="Add a field..."
            />
          </div>
          <input type="hidden" name="observation_field_id" value={ field && field.id } />
          <div className="taglist">
            { _.map( commonOfvs, ( t, i ) => {
              const key = `${t.observation_field.id}:${t.value}`;
              let tooltip = `${t.observation_field.name}: ` +
                `${( t.taxon && t.taxon.name ) ?
                     ( t.taxon.preferred_common_name || t.taxon.name ) : t.value}`;
              return (
                <OverlayTrigger
                  placement="top"
                  delayShow={ 1000 }
                  key={ `tt-ofv${i}` }
                  overlay={ ( <Tooltip id={ `tt-ofv${i}` }>{ tooltip }</Tooltip> ) }
                >
                  <Badge className="tag" key={ key }>
                    <span className="wrap">
                      <span className="field">{ `${t.observation_field.name}:` }</span>
                      { `${( t.taxon && t.taxon.name ) ?
                             ( t.taxon.preferred_common_name || t.taxon.name ) : t.value}` }
                    </span>
                    <Glyphicon glyph="remove-circle" onClick={ () => {
                      this.removeFieldValue( t );
                    } }
                    />
                  </Badge>
                </OverlayTrigger>
              );
            } ) }
          </div>
          { observationFieldInput }
        </form>
        <p className="options">
          <a href="/observation_fields" target="_blank">
            View Field Options
            <Glyphicon glyph="new-window" />
          </a>
        </p>
      </div>
    );
  }
}

LeftMenu.propTypes = {
  obsCards: PropTypes.object,
  observationField: PropTypes.object,
  observationFieldTaxon: PropTypes.object,
  observationFieldValue: PropTypes.any,
  observationFieldSelectedDate: PropTypes.string,
  appendToSelectedObsCards: PropTypes.func,
  removeFromSelectedObsCards: PropTypes.func,
  setState: PropTypes.func
};

export default LeftMenu;
