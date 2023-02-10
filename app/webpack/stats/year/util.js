import _ from "lodash";
import moment from "moment";

// Expects data as an array of objects that each have a date key that has a
// single YYYY-MM-DD date as a string. endYear is the last year it should fill
// gaps for. fillGap should be a function that accepts date (date of the gap)
// and prev (previous item in data by date)
function histogramWithoutGaps( data, opts, fillGap ) {
  const options = opts || {};
  if ( data.length === 0 ) return data;
  const sorted = _.sortBy( data, i => i.date );
  const minDate = sorted[0].date;
  // const minYear = minDate.year( );
  // const minMonth = minDate.month( ) + 1;
  const newData = [];
  // for ( let year = minYear; year <= endYear; year += 1 ) {
  //   const startMonth = ( year === minYear ) ? minMonth : 1;
  //   for ( let month = startMonth; month <= 12; month += 1 ) {
  //     const date = `${year}-${month < 10 ? `0${month}` : month}-01`;
  //     const interval = _.find( sorted, i => i.date === date );
  //     if ( interval ) {
  //       newData.push( interval );
  //     } else {
  //       const prev = _.findLast( sorted, i => i.date < date );
  //       newData.push( fillGap( date, prev ) );
  //     }
  //   }
  // }
  let date = moment( minDate );
  const endDate = options.endDate ? moment( options.endDate ) : moment( );
  const interval = options.interval || "month";
  while ( date < endDate ) {
    const dateString = date.format( "YYYY-MM-DD" );
    const existing = _.find( sorted, o => o.date === dateString );
    if ( existing ) {
      newData.push( existing );
    } else {
      const prev = _.findLast( sorted, o => o.date < dateString );
      newData.push( fillGap( dateString, prev ) );
    }
    date = moment( date ).add( 1, interval );
  }
  return newData;
}

function isTouchDevice() {
  // https://gist.github.com/59naga/ed6714519284d36792ba
  return navigator.userAgent.match(
    /(Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone)/i
  ) !== null;
}

export {
  histogramWithoutGaps,
  isTouchDevice
};
