import React, { createRef } from "react";
import PropTypes from "prop-types";
import moment from "moment";
import _ from "lodash";

import SelectionBasedComponent from "./selection_based_component";
import { parsableDatetimeFormat } from "../models/util";

class TimeShifter extends SelectionBasedComponent {
  constructor( props, context ) {
    super( props, context );

    this.state = {
      timeShift: 0
    };

    this.addTimeToSelectedObs = this.addTimeToSelectedObs.bind( this );
    this.subtractTimeFromSelectedObs = this.subtractTimeFromSelectedObs.bind( this );
    this.handleSlider = this.handleSlider.bind( this );
    this.handleValueChange = this.handleValueChange.bind( this );
    this.slider = createRef( );
    this.resetShifter = this.resetShifter.bind( this );
  }

  resetShifter( ) {
    this.setState( { timeShift: 0 } );
  }

  updateCard( card, newDate ) {
    const { updateObsCard, inputFormat } = this.props;

    let dateString = "";

    // using same datetime formats as date_time_field_wrapper.js
    dateString = newDate.format( inputFormat || parsableDatetimeFormat( ) );

    updateObsCard( card, {
      date: dateString,
      selected_date: dateString
    } );
    this.resetShifter( );
  }

  addTimeToSelectedObs( hours, minutes, cardsToUpdate ) {
    cardsToUpdate.forEach( card => {
      const { date } = card;
      if ( date === null ) { return; }

      const newDate = moment( new Date( date ) )
        .add( hours, "hours" )
        .add( minutes, "minutes" );
      const currentTime = moment( new Date( ) );

      const minDateString = moment.min( currentTime, newDate );

      if ( minDateString !== currentTime ) {
        this.updateCard( card, newDate );
      }
    } );
  }

  subtractTimeFromSelectedObs( hours, minutes, cardsToUpdate ) {
    cardsToUpdate.forEach( card => {
      const { date } = card;
      if ( date === null ) { return; }

      const newDate = moment( new Date( date ) )
        .subtract( hours, "hours" )
        .subtract( minutes, "minutes" );

      this.updateCard( card, newDate );
    } );
  }

  handleValueChange( ) {
    const { selectedObsCards } = this.props;
    const { timeShift } = this.state;
    const cardsToUpdate = _.keys( selectedObsCards ).map( card => selectedObsCards[card] );

    const isPositive = value => Math.sign( value ) === 1;
    const isNegative = value => Math.sign( value ) === -1;

    const hours = Math.abs( Math.trunc( timeShift ) );
    const minutes = Number.isInteger( timeShift ) ? 0 : 30;

    if ( isPositive( timeShift ) ) {
      this.addTimeToSelectedObs( hours, minutes, cardsToUpdate );
    }

    if ( isNegative( timeShift ) ) {
      this.subtractTimeFromSelectedObs( hours, minutes, cardsToUpdate );
    }
  }

  handleSlider( ) {
    if ( this.slider.current && this.slider.current.value ) {
      this.setState( {
        timeShift: Number( this.slider.current.value )
      } );
    }
  }

  render( ) {
    const { timeShift } = this.state;
    return (
      <div className="slider-group">
        <p className="panel-group current-hours">
          {I18n.t( "hours_to_adjust" )}
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
        <div className={`time-shifter-buttons btn-toolbar ${timeShift === 0 && "hidden"}`}>
          <button className="btn btn-sm btn-primary" type="button" onClick={this.handleValueChange}>
            {I18n.t( "offset_time_verb" )}
          </button>
          <button className="btn btn-sm btn-default" type="button" onClick={this.resetShifter}>
            {I18n.t( "cancel" )}
          </button>
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
