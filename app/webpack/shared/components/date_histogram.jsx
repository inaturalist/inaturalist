import React from "react";
import {
  timeDay,
  timeFormat,
  timeHour,
  timeMinute,
  timeMonth,
  timeSecond,
  timeWeek,
  timeYear
} from "d3";
import moment from "moment";
import Histogram from "./histogram";

const DateHistogram = props => {
  const defaultTickFormatBottom = d => {
    const md = moment( d );
    if ( timeSecond( d ) < d ) return md.format( ".SSS" );
    if ( timeMinute( d ) < d ) return md.format( ":s" );
    if ( timeHour( d ) < d ) return md.format( "hh:mm" );
    if ( timeDay( d ) < d ) return md.format( "h A" );
    if ( timeMonth( d ) < d ) {
      // if ( timeWeek( d ) < d ) return md.format( "MMM D" );
      return md.format( "MMM D" );
    }
    if ( timeYear( d ) < d ) return md.format( "MMM D" );
    return md.format( "YYYY" );
  };
  const newProps = Object.assign( { }, props, {
    xAttr: "date",
    xParser: date => moment( date ).toDate( ),
    xFormatter: timeFormat( "%d %b" ),
    className: `DateHistogram ${props.className}`,
    tickFormatBottom: props.tickFormatBottom || defaultTickFormatBottom
  } );
  return <Histogram {...newProps} />;
};

export default DateHistogram;
