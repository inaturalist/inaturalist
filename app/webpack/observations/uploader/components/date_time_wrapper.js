import React, { Component } from "react";
import PropTypes from "prop-types";
import Datetime from "react-datetime";
import moment from "moment-timezone";
import { DATE_ONLY, TIME_WITH_TIMEZONE, DATETIME_WITH_TIMEZONE, DATETIME_WITH_TIMEZONE_OFFSET } from "../models/util";

class DateTimeWrapper extends Component {

  constructor( props ) {
    super( props );
    this.onClick = this.onClick.bind( this );
    this.onChange = this.onChange.bind( this );
    this.pickerState = this.pickerState.bind( this );
    this.valid = this.valid.bind( this );
  }

  /*componentDidMount( ) {
    // the datetime picker prevents a card drag preview without this
    this.close( );
  }*/

  shouldComponentUpdate( nextProps ) {
    if ( this.props.reactKey === nextProps.reactKey ) { return false; }
    return true;
  }

  onClick( ) {
    if ( this.datetime ) {
      this.datetime.onClick( );
    }
  }

  onChange( fieldValue ) {
    const { timeZone, dateFormat, timeFormat } = this.props;
    let value = fieldValue;
    if ( moment.isMoment(value) ) {
      const pickedDate = value.toDate();
      if ( pickedDate ) {
        let format = dateFormat
        if ( timeFormat ) {
          format = `${ format } ${ timeFormat }`
        }
        if ( timeZone ) {
          value = value.tz( timeZone ).format( format || DATETIME_WITH_TIMEZONE );
        } else {
          value = moment.parseZone( pickedDate ).format( format || DATETIME_WITH_TIMEZONE_OFFSET );
        }
      }
    }
    this.props.onChange( value );
  }

  pickerState( ) {
    if ( this.datetime ) { return this.datetime.state; }
    return undefined;
  }

  valid(current) {
    return this.props.allowFutureDates || current.isBefore( ); //No param checks for before the current date/time.
  }

  render( ) {
    return (
      <Datetime 
        ref={ ref => this.datetime = ref }
        key="datetime"
        className="datetime"
        inputProps={ this.props.inputProps }
        locale={ I18n.locale }
        value={ this.props.dateTime || this.props.defaultText }
        dateFormat={ this.props.dateFormat }
        timeFormat={ this.props.timeFormat }
        displayTimeZone= { this.props.timezone }
        closeOnSelect={ true }
        isValidDate={ this.valid }
        onChange={ this.onChange }
      />
    );
  }
}

DateTimeWrapper.propTypes = {
  inputProps: PropTypes.object,
  onChange: PropTypes.func,
  onSelection: PropTypes.func,
  reactKey: PropTypes.string,
  defaultText: PropTypes.string,
  timeZone: PropTypes.string,
  dateFormat: PropTypes.string,
  timeFormat: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.bool
  ] ),
  allowFutureDates: PropTypes.bool,
  dateTime: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number,
    PropTypes.object
  ] )
};

DateTimeWrapper.defaultProps = {
  dateFormat: DATE_ONLY,
  timeFormat: TIME_WITH_TIMEZONE,
}

export default DateTimeWrapper;
