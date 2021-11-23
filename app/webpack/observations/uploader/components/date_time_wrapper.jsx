import React, { Component } from "react";
import { Glyphicon } from "react-bootstrap";
import PropTypes from "prop-types";
import Datetime from "react-datetime";
import moment from "moment-timezone";
import {
  DATE_ONLY, TIME_WITH_TIMEZONE, DATETIME_WITH_TIMEZONE, DATETIME_WITH_TIMEZONE_OFFSET
} from "../models/util";

class DateTimeWrapper extends Component {
  constructor( props ) {
    super( props );
    this.onClick = this.onClick.bind( this );
    this.onChange = this.onChange.bind( this );
    this.valid = this.valid.bind( this );
    this.renderInputWithOpenButton = this.renderInputWithOpenButton.bind( this );
    this.toggleCalendar = this.toggleCalendar.bind( this );
  }

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
    if ( moment.isMoment( value ) ) {
      const pickedDate = value.toDate();
      if ( pickedDate ) {
        let format = dateFormat || timeFormat;
        if ( dateFormat && timeFormat ) {
          format = `${format} ${timeFormat}`;
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

  valid( current ) {
    // isBefore( ) checks for before the current date/time.
    return this.props.allowFutureDates || current.isBefore( );
  }

  toggleCalendar( openCalendar, closeCalendar ) {
    if ( this.datetime.isOpen() ) {
      closeCalendar();
    } else {
      openCalendar();
    }
  }

  renderInputWithOpenButton( props, openCalendar, closeCalendar ) {
    const openButtonOnClick = () => { this.toggleCalendar( openCalendar, closeCalendar ); };
    return (
      <div className="input-group date">
        {this.renderOpenButton( "before", openButtonOnClick )}
        <input {...props} />
        {this.renderOpenButton( "after", openButtonOnClick )}
      </div>
    );
  }

  renderOpenButton( position, onClick ) {
    if ( position === this.props.openButton ) {
      return (
        <span
          className={`input-group-addon ${this.props.openButtonClassName}`}
          role="button"
          onClick={onClick}
          onKeyPress={onClick}
          tabIndex="0"
        >
          <Glyphicon glyph="calendar" />
        </span>
      );
    }
    return "";
  }

  render( ) {
    return (
      <Datetime
        ref={ref => { this.datetime = ref; }}
        key="datetime"
        className="datetime"
        inputProps={this.props.inputProps}
        renderInput={this.props.openButton ? this.renderInputWithOpenButton : undefined}
        locale={I18n.locale}
        initialValue={this.props.dateTime}
        dateFormat={this.props.dateFormat}
        timeFormat={this.props.timeFormat}
        displayTimeZone={this.props.timeZone}
        closeOnSelect
        isValidDate={this.valid}
        onChange={this.onChange}
      />
    );
  }
}

DateTimeWrapper.propTypes = {
  inputProps: PropTypes.object,
  onChange: PropTypes.func,
  onSelection: PropTypes.func,
  reactKey: PropTypes.string,
  timeZone: PropTypes.string,
  dateFormat: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.bool
  ] ),
  timeFormat: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.bool
  ] ),
  allowFutureDates: PropTypes.bool,
  openButton: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.bool
  ] ),
  openButtonClassName: PropTypes.string,
  dateTime: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number,
    PropTypes.object
  ] )
};

DateTimeWrapper.defaultProps = {
  dateFormat: DATE_ONLY,
  timeFormat: TIME_WITH_TIMEZONE,
  openButton: false
};

export default DateTimeWrapper;
