import React, { createRef } from "react";
import PropTypes from "prop-types";
import moment from "moment";
import _ from "lodash";

import SelectionBasedComponent from "./selection_based_component";
import { DATETIME_WITH_TIMEZONE_OFFSET } from "../models/util";

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
    this.slider = createRef( );
  }

  updateCard( card, dateString ) {
    const { updateObsCard } = this.props;
    updateObsCard( card, {
      date: dateString,
      selected_date: dateString
    } );
  }

  addTimeToSelectedObs( hours, minutes, cardsToUpdate ) {
    const { inputFormat } = this.props;

    cardsToUpdate.forEach( card => {
      const { date } = card;
      if ( date === null ) { return; }

      const newDate = moment( new Date( date ) )
        .add( hours, "hours" )
        .add( minutes, "minutes" );
      const currentTime = moment( new Date( ) );

      const minDateString = moment.min( currentTime, newDate );
      const dateString = newDate.tz( card.time_zone ).format( inputFormat );

      if ( minDateString !== currentTime ) {
        this.updateCard( card, dateString );
      }
    } );
  }

  subtractTimeFromSelectedObs( hours, minutes, cardsToUpdate ) {
    const { inputFormat } = this.props;

    cardsToUpdate.forEach( card => {
      const { date } = card;
      if ( date === null ) { return; }

      const dateString = moment( new Date( date ) )
        .tz( card.time_zone )
        .subtract( hours, "hours" )
        .subtract( minutes, "minutes" )
        .format( inputFormat );

      this.updateCard( card, dateString );
    } );
  }

  handleValueChange( ) {
    const { selectedObsCards } = this.props;
    const cardsToUpdate = _.keys( selectedObsCards ).map( card => selectedObsCards[card] );

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
      this.addTimeToSelectedObs( hours, minutes, cardsToUpdate );
    }

    if ( isNegative( amountToShift ) ) {
      this.subtractTimeFromSelectedObs( hours, minutes, cardsToUpdate );
    }
  }

  handleSlider( ) {
    if ( this.slider.current && this.slider.current.value ) {
      this.setState( {
        timeShift: Number( this.slider.current.value )
      }, ( ) => this.handleValueChange( ) );
    }
  }

  render( ) {
    const { timeShift } = this.state;
    return (
      <div className="slider-group">
        <p className="panel-group current-hours">
          {I18n.t( "hours_adjusted" )}
          <span className="new-time">{timeShift}</span>
        </p>
        <div className="slidecontainer">
          <input
            ref={this.slider}
            type="range"
            min="-24"
            max="24"
            step="0.5"
            value={timeShift}
            className="slider"
            onChange={this.handleSlider}
            list="tickmarks"
          />
        </div>
        <div className="tickmarks">
          {[-24, -12, 0, 12, 24].map( tick => <span className="tick" key={tick.toString( )}>{tick}</span> )}
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

TimeShifter.defaultProps = {
  inputFormat: DATETIME_WITH_TIMEZONE_OFFSET
};

export default TimeShifter;
