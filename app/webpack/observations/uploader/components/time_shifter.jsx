import React from "react";
import PropTypes from "prop-types";
import moment from "moment";
import _ from "lodash";

import SelectionBasedComponent from "./selection_based_component";

class TimeShifter extends SelectionBasedComponent {
  constructor( props, context ) {
    super( props, context );

    this.state = {
      timeShift: 0,
      prevTimeShift: 0
    };


    this.addTimeToSelectedObs = this.addTimeToSelectedObs.bind( this );
    this.subtractTimeFromSelectedObs = this.subtractTimeFromSelectedObs.bind( this );
    this.handleSlider = this.handleSlider.bind( this );
    this.handleValueChange = this.handleValueChange.bind( this );
  }

  componentDidMount( ) {
    const output = document.getElementById( "newTime" );
    output.innerHTML = 0; // Display the default slider value
  }

  updateCard( card, dateString, amountToShift ) {
    const { updateObsCard } = this.props;
    updateObsCard( card, {
      date: dateString,
      selected_date: dateString
      // time_shifted: amountToShift
    } );
  }

  addTimeToSelectedObs( hours, minutes, amountToShift ) {
    const { selectedObsCards, inputFormat } = this.props;

    const cardsToUpdate = _.keys( selectedObsCards ).map( card => selectedObsCards[card] );

    cardsToUpdate.forEach( card => {
      const { date } = card;
      const newDate = moment( new Date( date ) )
        .add( hours, "hours" )
        .add( minutes, "minutes" );
      const currentTime = moment( new Date( ) );

      const minDateString = moment.min( currentTime, newDate );
      const dateString = newDate.tz( card.time_zone ).format( inputFormat || "YYYY/MM/DD h:mm A ZZ" );

      // we need some way to let a user know that one of these dates is no longer updating
      if ( minDateString !== currentTime ) {
        this.updateCard( card, dateString, amountToShift );
      }
    } );
  }

  subtractTimeFromSelectedObs( hours, minutes, amountToShift ) {
    const { selectedObsCards, inputFormat } = this.props;

    const cardsToUpdate = _.keys( selectedObsCards ).map( card => selectedObsCards[card] );

    cardsToUpdate.forEach( card => {
      const { date } = card;
      const dateString = moment( new Date( date ) )
        .tz( card.time_zone )
        .subtract( hours, "hours" )
        .subtract( minutes, "minutes" )
        .format( inputFormat || "YYYY/MM/DD h:mm A ZZ" );

      this.updateCard( card, dateString, amountToShift );
    } );
  }

  handleValueChange( ) {
    const isPositive = value => Math.sign( value ) === 1;
    const isNegative = value => Math.sign( value ) === -1;

    const diff = ( a, b ) => {
      if ( a > b ) {
        return a - b;
      }
      return b - a;
    };

    const {
      timeShift: value,
      prevTimeShift
    } = this.state;

    const amountToShift = value > prevTimeShift
      ? diff( value, prevTimeShift )
      : -diff( value, prevTimeShift );

    this.setState( { prevTimeShift: value } );

    const hours = Math.abs( Math.trunc( amountToShift ) );
    const minutes = Number.isInteger( amountToShift ) ? 0 : 30;

    if ( isPositive( amountToShift ) ) {
      this.addTimeToSelectedObs( hours, minutes, amountToShift );
    }

    if ( isNegative( amountToShift ) ) {
      this.subtractTimeFromSelectedObs( hours, minutes, amountToShift );
    }
  }

  handleSlider( ) {
    // adapted from https://www.w3schools.com/howto/howto_js_rangeslider.asp
    const slider = document.getElementById( "timeShifter" );
    const output = document.getElementById( "newTime" );
    const { value } = slider;
    output.innerHTML = value; // Display the default slider value

    this.setState( { timeShift: Number( value ) }, ( ) => this.handleValueChange( ) );

    // Update the current slider value (each time you drag the slider handle)
    slider.oninput = ( ) => {
      output.innerHTML = this.value;
      // slider.innerHTML = "clock";
    };
  }

  render( ) {
    const { timeShift } = this.state;
    return (
      <div className="slider-group">
        <p className="panel-group current-hours">
          {I18n.t( "hours_adjusted" )}
          <span id="newTime" />
        </p>
        <div className="slidecontainer">
          <input
            type="range"
            min="-24"
            max="24"
            step="0.5"
            value={timeShift}
            className="slider"
            id="timeShifter"
            onChange={this.handleSlider}
            list="tickmarks"
          />
          <div className="tickmarks">
            <span className="tick">-24</span>
            <span className="tick">-12</span>
            <span className="tick">0</span>
            <span className="tick">12</span>
            <span className="tick">24</span>
          </div>
        </div>
      </div>
    );
  }
}

TimeShifter.propTypes = {
  inputFormat: PropTypes.string,
  dateTime: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number,
    PropTypes.object
  ] ),
  selectedObsCards: PropTypes.object,
  updateObsCard: PropTypes.func
};

export default TimeShifter;
