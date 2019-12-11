import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import moment from "moment";
import { color as d3color } from "d3";
import { COLORS } from "../../../shared/util";
import { histogramWithoutGaps } from "../util";
import DateHistogram from "./date_histogram";
import CountryGrowth from "./country_growth";

const Growth = ( {
  data,
  year,
  site
} ) => {
  const label = d => I18n.t( "bold_label_colon_value_html", {
    label: moment( d.date ).add( 2, "days" ).format( "MMMM YYYY" ),
    value: I18n.t( "x_observations", { count: I18n.toNumber( d.value, { precision: 0 } ) } )
  } );
  const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
  const emptyJan = {
    date: `${year + 1}-01-01`,
    total: 0,
    novel: 0,
    value: 0
  };
  const endDate = `${year + 1}-01-01`;
  let runningTotal = 0;
  let obsData = _.map(
    _.map( data.observations, ( value, date ) => ( { date, value } ) ),
    interval => {
      runningTotal += interval.value;
      return {
        date: interval.date,
        total: runningTotal,
        novel: interval.value
      };
    }
  );
  obsData = histogramWithoutGaps( obsData, { endDate }, ( date, prev ) => ( {
    date,
    total: prev ? prev.total : 0,
    novel: 0
  } ) );
  obsData.push( emptyJan );
  const obsSeries = {
    novelThisYear: {
      title: I18n.t( "new_observations_in_year", { year } ),
      style: "bar",
      data: obsData.map( interval => ( {
        date: interval.date,
        value: interval.novel,
        offset: interval.total - interval.novel
      } ) ).filter( interval => interval.date >= `${year}-01-01` ),
      color: COLORS.inatGreen,
      label
    },
    novel: {
      title: I18n.t( "new_observations" ),
      style: "bar",
      data: obsData.map( interval => ( {
        date: interval.date,
        value: interval.novel,
        offset: interval.total - interval.novel
      } ) ).filter( interval => interval.date < `${year}-01-01` ),
      color: d3color( COLORS.inatGreen ).darker( 2.0 ),
      label
    },
    total: {
      title: I18n.t( "running_total" ),
      style: "bar",
      data: obsData.map( interval => ( { date: interval.date, value: interval.total } ) ),
      color: grayColor,
      label
    }
  };
  let taxaSeries;
  if ( data.taxa ) {
    const taxaData = histogramWithoutGaps( data.taxa, { endDate }, ( date, prev ) => ( {
      date,
      accumulated_species_count: prev ? prev.accumulated_species_count : 0,
      novel_species_ids: []
    } ) );
    taxaData.push( {
      date: `${year + 1}-01-01`,
      accumulated_species_count: 0,
      novel_species_ids: []
    } );
    taxaSeries = {
      novelThisYear: {
        title: I18n.t( "newly_observed_species_in_year", { year } ),
        style: "bar",
        data: _.map( taxaData, i => ( {
          date: i.date,
          value: i.novel_species_ids.length,
          offset: i.accumulated_species_count - i.novel_species_ids.length
        } ) ).filter( interval => interval.date >= `${year}-01-01` ),
        color: COLORS.iconic.Insecta,
        label
      },
      novel: {
        title: I18n.t( "newly_observed_species" ),
        style: "bar",
        data: _.map( taxaData, i => ( {
          date: i.date,
          value: i.novel_species_ids.length,
          offset: i.accumulated_species_count - i.novel_species_ids.length
        } ) ).filter( interval => interval.date < `${year}-01-01` ),
        color: d3color( COLORS.iconic.Insecta ).darker( 2.0 ),
        label
      },
      total: {
        title: I18n.t( "running_total" ),
        style: "bar",
        data: _.map( taxaData, i => ( {
          date: i.date,
          value: i.accumulated_species_count
        } ) ),
        color: grayColor,
        label
      }
    };
  }
  runningTotal = 0;
  const sortedUserData = _.map(
    _.sortBy( _.map( data.users, ( value, date ) => ( { date, value } ) ), i => i.date ),
    i => {
      runningTotal += i.value;
      return {
        date: i.date,
        total: runningTotal,
        novel: i.value
      };
    }
  );
  const userData = histogramWithoutGaps( sortedUserData, { endDate }, ( date, prev ) => ( {
    date,
    total: prev ? prev.total : 0,
    novel: 0
  } ) );
  userData.push( emptyJan );
  const usersSeries = {
    novelThisYear: {
      title: I18n.t( "new_users_in_year", { year } ),
      style: "bar",
      data: userData.map( interval => ( {
        date: interval.date,
        value: interval.novel,
        offset: interval.total - interval.novel
      } ) ).filter( interval => interval.date >= `${year}-01-01` ),
      color: COLORS.iconic.Animalia,
      label
    },
    novel: {
      title: I18n.t( "new_users" ),
      style: "bar",
      data: userData.map( interval => ( {
        date: interval.date,
        value: interval.novel,
        offset: interval.total - interval.novel
      } ) ).filter( interval => interval.date < `${year}-01-01` ),
      color: d3color( COLORS.iconic.Animalia ).darker( 2.0 ),
      label
    },
    total: {
      title: I18n.t( "running_total" ),
      style: "bar",
      data: userData.map( interval => ( { date: interval.date, value: interval.total } ) ),
      color: grayColor,
      label
    }
  };
  const obsTotalDates = obsSeries.total.data.map( d => d.date );
  const xExtent = [obsTotalDates[0], obsTotalDates[obsTotalDates.length - 1]];
  return (
    <div className="Growth">
      <h3>
        <a name="growth" href="#growth">
          <span>{ I18n.t( "views.stats.year.growth_title" ) }</span>
        </a>
      </h3>
      { site && (
        <p className="text-muted">
          { I18n.t( "views.stats.year.growth_desc", { site_name: site.name } ) }
        </p>
      ) }
      <DateHistogram
        series={obsSeries}
        legendPosition="nw"
        margin={{ left: 60 }}
        xExtent={xExtent}
      />
      { taxaSeries && (
        <DateHistogram
          series={taxaSeries}
          legendPosition="nw"
          margin={{ left: 60 }}
          xExtent={xExtent}
        />
      ) }
      <DateHistogram
        series={usersSeries}
        legendPosition="nw"
        margin={{ left: 60 }}
        xExtent={xExtent}
      />
      { data.countries && <CountryGrowth data={data.countries} year={year} /> }
    </div>
  );
};

Growth.propTypes = {
  data: PropTypes.object,
  year: PropTypes.number,
  site: PropTypes.object
};

export default Growth;
