import _ from "lodash";
import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input, Button } from "react-bootstrap";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import DateTimeFieldWrapper from "../../uploader/components/date_time_field_wrapper";

class ObservationFieldInput extends React.Component {

  constructor( props, context ) {
    super( props, context );
    this.state = {
      observationField: this.props.observationField,
      observationFieldValue: this.props.observationFieldValue,
      observationFieldTaxon: this.props.observationFieldTaxon
    };
    this.submitFieldValue = this.submitFieldValue.bind( this );
  }

  componentDidMount( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  componentDidUpdate( ) {
    this.setUpObservationFieldAutocomplete( );
  }

  setUpObservationFieldAutocomplete( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const input = $( domNode ).find( ".ofv-field" );
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
        if ( items !== null && items.length === 0 && input.val( ).length > 0 ) {
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
    const value = $( e.target ).find( "[name='value']" );
    if ( !this.state.observationField ) { return; }
    if ( !this.state.observationFieldValue && !value.val( ) ) {
      const valueInput = $( e.target ).find( "[name='value'], [name='taxon_name']" );
      valueInput.addClass( "failed" );
      setTimeout( () => {
        valueInput.removeClass( "failed" );
      }, 1000 );
      return;
    }
    if ( this.state.observationField.datatype === "taxon" ) {
      this.props.onSubmit( {
        observationField: this.state.observationField,
        value: this.state.observationFieldValue,
        taxon: this.state.observationFieldTaxon
      } );
    } else if ( value ) {
      this.props.onSubmit( {
        observationField: this.state.observationField,
        value: value.val( )
      } );
    }
    this.reset( );
  }

  reset( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const value = $( domNode ).find( "[name='value']" );
    const input = $( domNode ).find( "input.ofv-input" );
    this.setState( {
      observationField: null,
      observationFieldValue: null,
      observationFieldTaxon: null
    } );
    value.val( "" );
    input.val( "" ).blur( );
  }

  selectInput( field ) {
    return (
      <Input type="select" name="value" defaultValue={ this.state.observationFieldValue }>
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
          initialSelection={ this.state.observationFieldTaxon }
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
            { this.props.editing ? I18n.t( "save" ) : I18n.t( "add" ) }
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
            { this.props.editing ? I18n.t( "save" ) : I18n.t( "add" ) }
          </button>
        </span>
      </div>
    );
  }

  dnaInput( ) {
    return ( <textarea
      name="value"
      className="form-control"
      defaultValue={ this.state.observationFieldValue }
    /> );
  }

  defaultInput( ) {
    return (
      <div className="input-group">
        <input
          type="text"
          name="value"
          defaultValue={ this.state.observationFieldValue }
          className="form-control"
        />
        <span className="input-group-btn">
          <button
            className="btn btn-default"
            type="submit"
          >
            { this.props.editing ? I18n.t( "save" ) : I18n.t( "add" ) }
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
          { this.props.editing ? I18n.t( "save" ) : I18n.t( "add" ) }
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
        <div className={ `observation-field ${this.props.editing ? "editing" : ""}` }>
          <div className="field-name">{ field.name }</div>
          { input }
          <p className="help-block">{ field.description }</p>
          { submit } <span
            className="linky"
            onClick={ ( ) => (
              this.props.onCancel ? this.props.onCancel( ) : this.reset( )
            ) }
          >{ I18n.t( "cancel" ) }</span>
        </div>
      );
    }
    const fieldChooser = this.props.hideFieldChooser ? "" : (
      <input type="text"
        placeholder={ this.props.placeholder }
        className="form-control ofv-field"
      /> );
    return (
      <form onSubmit={ this.submitFieldValue }>
        { fieldChooser }
        { observationFieldInput }
      </form>
    );
  }
}

ObservationFieldInput.propTypes = {
  observationField: PropTypes.object,
  observationFieldTaxon: PropTypes.object,
  observationFieldValue: PropTypes.any,
  editing: PropTypes.bool,
  hideFieldChooser: PropTypes.bool,
  notIDs: PropTypes.array,
  onSubmit: PropTypes.func,
  onCancel: PropTypes.func,
  placeholder: PropTypes.string
};

ObservationFieldInput.defaultProps = {
  placeholder: I18n.t( "choose_a_field" )
};

export default ObservationFieldInput;
