import _ from "lodash";
import moment from "moment-timezone";
import React, { PropTypes } from "react";
import { Input, Button } from "react-bootstrap";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import DateTimeFieldWrapper from "../../uploader/components/date_time_field_wrapper";

class ObservationFieldInput extends React.Component {

  constructor( props, context ) {
    super( props, context );
    this.state = { };
    this.taxonInput = this.taxonInput.bind( this );
    this.datetimeInput = this.datetimeInput.bind( this );
    this.submitFieldValue = this.submitFieldValue.bind( this );
  }

  componentDidMount( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  componentDidUpdate( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  setUpObservationFieldAutocomplete( ) {
    const input = $( ".ObservationFields .panel-collapse .ofv-field" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.autocomplete( "destroy" );
      input.removeData( "uiAutocomplete" );
    }
    input.observationFieldAutocomplete( {
      resetOnChange: false,
      allowEnterSubmit: false,
      selectFirstMatch: true,
      notIDs: this.props.notIDs,
      idEl: $( "<input/>" ),
      onResults: items => {
        if ( items !== null && items.length === 0 ) {
          input.addClass( "failed" );
        } else {
          input.removeClass( "failed" );
        }
      },
      afterSelect: p => {
        if ( p ) {
          this.setState( {
            observationField: p.item,
            observationFieldValue: null,
            observationFieldSelectedDate: null
          } );
        }
        input.val( "" ).blur( );
      }
    } );
  }

  submitFieldValue( e ) {
    e.preventDefault( );
    const observationFieldID = $( e.target ).find( "input[name='observation_field_id']" );
    const value = $( e.target ).find( "[name='value']" );
    const input = $( e.target ).find( "input.ofv-input" );
    if ( !this.state.observationFieldValue && !value.val( ) ) {
      const valueInput = $( e.target ).find( "[name='value'], [name='taxon_name']" );
      valueInput.addClass( "failed" );
      setTimeout( () => {
        valueInput.removeClass( "failed" );
      }, 1000 );
      return;
    }
    if ( this.state.observationField && this.state.observationFieldValue ) {
      this.props.onSubmit( {
        observationField: this.state.observationField,
        value: this.state.observationFieldValue,
        taxon: this.state.observationFieldTaxon
      } );
    } else if ( observationFieldID && value ) {
      this.props.onSubmit( {
        observationField: this.state.observationField,
        value: value.val( )
      } );
    }
    this.setState( {
      observationField: null,
      observationFieldValue: null,
      observationFieldTaxon: null
    } );
    observationFieldID.val( "" );
    value.val( "" );
    input.val( "" ).blur( );
  }

  selectInput( field ) {
    return (
      <Input type="select" name="value" >
        { _.map( field.allowed_values.split( "|" ), f => (
          <option value={ f } key={ f }>{ f }</option>
        ) ) }
      </Input>
    );
  }

  taxonInput( ) {
    return (
      <div className="input-group">
        <TaxonAutocomplete
          bootstrap
          searchExternal
          showPlaceholder={ false }
          perPage={ 6 }
          afterSelect={ r => {
            this.setState( {
              observationFieldTaxon: r.item,
              observationFieldValue: r.item.id
            } );
          } }
          afterUnselect={ ( ) => {
            this.setState( {
              observationFieldTaxon: null,
              observationFieldValue: null
            } );
          } }
          placeholder={ I18n.t( "species_name_cap" ) }
        />
        <span className="input-group-btn">
          <button
            className="btn btn-default"
            type="submit"
          >
            { I18n.t( "add" ) }
          </button>
        </span>
      </div>
    );
  }

  datetimeInput( datatype ) {
    /* global TIMEZONE */
    let mode;
    if ( datatype === "time" ) {
      mode = "time";
    } else if ( datatype === "date" ) {
      mode = "date";
    }
    let format = "YYYY/MM/DD h:mm A z";
    if ( datatype === "time" ) {
      format = "HH:mm";
    } else if ( datatype === "date" ) {
      format = "YYYY/MM/DD";
    }
    return (
      <div className="input-group">
        <DateTimeFieldWrapper
          key={ `datetime${this.state.observationFieldSelectedDate}`}
          reactKey={ `datetime${this.state.observationFieldSelectedDate}`}
          ref="datetime"
          mode={ mode }
          inputFormat={ format }
          timeZone={ TIMEZONE }
          onChange={ dateString =>
            this.setState( { observationFieldValue: dateString } ) }
          onSelection={ dateString =>
            this.setState( {
              observationFieldValue: dateString,
              observationFieldSelectedDate: dateString
            } )
          }
        />
        <input
          type="text"
          name="value"
          className="form-control"
          autoComplete="off"
          value={ this.state.observationFieldValue }
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
          placeholder={ I18n.t( "date_time" ) }
        />
        <span className="input-group-btn">
          <button
            className="btn btn-default"
            type="submit"
          >
            { I18n.t( "add" ) }
          </button>
        </span>
      </div>
    );
  }

  dnaInput( ) {
    return ( <textarea name="value" className="form-control" /> );
  }

  defaultInput( ) {
    return (
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
            { I18n.t( "add" ) }
          </button>
        </span>
      </div>
    );
  }

  render( ) {
    const field = this.state.observationField;
    let observationFieldInput;
    if ( field ) {
      let input;
      let submit;
      const standaloneSubmit = (
        <Button className="standalone" type="submit">
          { I18n.t( "add" ) }
        </Button>
      );
      if ( field.allowed_values ) {
        input = this.selectInput( field );
        submit = standaloneSubmit;
      } else if ( field.datatype === "taxon" ) {
        input = this.taxonInput( );
      } else if ( field.datatype === "dna" ) {
        input = this.dnaInput( );
        submit = standaloneSubmit;
      } else if ( field.datatype === "datetime" ||
                  field.datatype === "time" ||
                  field.datatype === "date" ) {
        input = this.datetimeInput( field.datatype );
      } else {
        input = this.defaultInput( );
      }
      observationFieldInput = (
        <div className="observation-field">
          <div className="field-name">{ field.name }</div>
          { input }
          <p className="help-block">{ field.description }</p>
          { submit }
        </div>
      );
    }
    return (
      <form onSubmit={ this.submitFieldValue }>
        <input type="text" placeholder="Choose a field" className="form-control ofv-field" />
        { observationFieldInput }
      </form>
    );
  }
}

ObservationFieldInput.propTypes = {
  observationField: PropTypes.object,
  notIDs: PropTypes.array,
  onSubmit: PropTypes.func
};

export default ObservationFieldInput;
