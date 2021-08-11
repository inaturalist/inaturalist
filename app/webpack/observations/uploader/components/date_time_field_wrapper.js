import React, { Component } from "react";
import PropTypes from "prop-types";
import DateTimeField from "react-bootstrap-datetimepicker";
import moment from "moment-timezone";
import { DATETIME_WITH_TIMEZONE, DATETIME_WITH_TIMEZONE_OFFSET } from "../models/util";

class DateTimeFieldWrapper extends Component {

  constructor( props, context ) {
    super( props, context );
    this.onClick = this.onClick.bind( this );
    this.onChange = this.onChange.bind( this );
    this.close = this.close.bind( this );
    this.pickerState = this.pickerState.bind( this );
  }

  componentDidMount( ) {
    // the datetime picker prevents a card drag preview without this
    this.close( );
  }

  shouldComponentUpdate( nextProps ) {
    if ( this.props.reactKey === nextProps.reactKey ) { return false; }
    return true;
  }

  onClick( ) {
    if ( this.refs.datetime ) {
      this.refs.datetime.onClick( );
    }
  }

  onChange( e, inputValue ) {
    const { timeZone, inputFormat } = this.props;
    let value = inputValue;
    const eInt = parseInt( e, 10 );
    if ( e && eInt ) {
      const pickedDate = new Date( eInt );
      if ( pickedDate ) {
        if ( timeZone ) {
          value = moment( pickedDate ).tz( timeZone ).format( inputFormat || DATETIME_WITH_TIMEZONE );
        } else {
          value = moment.parseZone( pickedDate ).format( inputFormat || DATETIME_WITH_TIMEZONE_OFFSET );
        }
      }
    }
    this.props.onChange( value );
  }

  close( ) {
    if ( this.refs.datetime ) { this.refs.datetime.closePicker( ); }
  }

  pickerState( ) {
    if ( this.refs.datetime ) { return this.refs.datetime.state; }
    return undefined;
  }

  render( ) {
    return (
      <DateTimeField
        ref="datetime"
        key="datetime"
        className="datetime"
        mode={ this.props.mode }
        size={ this.props.size }
        maxDate={ this.props.allowFutureDates ? null : moment( ) }
        inputProps={ this.props.inputProps }
        defaultText={ this.props.defaultText || "" }
        dateTime={ this.props.dateTime }
        inputFormat={this.props.inputFormat || DATETIME_WITH_TIMEZONE_OFFSET}
        onChange={ this.onChange }
      />
    );
  }
}

DateTimeFieldWrapper.propTypes = {
  inputProps: PropTypes.object,
  onChange: PropTypes.func,
  onSelection: PropTypes.func,
  reactKey: PropTypes.string,
  defaultText: PropTypes.string,
  timeZone: PropTypes.string,
  mode: PropTypes.string,
  inputFormat: PropTypes.string,
  size: PropTypes.string,
  allowFutureDates: PropTypes.bool,
  dateTime: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number,
    PropTypes.object
  ] )
};

export default DateTimeFieldWrapper;
