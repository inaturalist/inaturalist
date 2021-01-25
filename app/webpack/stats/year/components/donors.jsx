import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment";
import { COLORS } from "../../../shared/util";
import DateHistogram from "../../../shared/components/date_histogram";

const Donations = ( {
  year,
  data
} ) => {
  // const donationSeries = {
  //   total: {
  //     data: data.map( d => ( {
  //       date: d.date,
  //       value: d.total_net_amount_usd
  //     } ) )
  //   },
  //   recurring: {
  //     data: data.map( d => ( {
  //       date: d.date,
  //       value: d.recurring_net_amount_usd
  //     } ) )
  //   },
  //   monthly: {
  //     data: data.map( d => ( {
  //       date: d.date,
  //       value: d.monthly_net_amount_usd
  //     } ) )
  //   }
  // };
  // const donorSeries = {
  //   total: {
  //     data: data.map( d => ( {
  //       date: d.date,
  //       value: d.total_donors
  //     } ) )
  //   },
  //   recurring: {
  //     data: data.map( d => ( {
  //       date: d.date,
  //       value: d.recurring_donors
  //     } ) )
  //   },
  //   monthly: {
  //     data: data.map( d => ( {
  //       date: d.date,
  //       value: d.monthly_donors
  //     } ) )
  //   }
  // };
  const label = d => I18n.t( "bold_label_colon_value_html", {
    label: moment( d.date ).add( 2, "days" ).format( "MMMM YYYY" ),
    value: I18n.toNumber( d.value, { precision: 0 } )
  } );
  const donorBarSeries = {
    recurring: {
      title: I18n.t( "views.stats.year.recurring" ),
      style: "bar",
      color: COLORS.mediumGray,
      label,
      data: data.map( d => ( {
        date: d.date,
        value: d.recurring_donors
      } ) )
    },
    total: {
      title: I18n.t( "views.stats.year.one_time" ),
      style: "bar",
      color: "#555",
      label,
      data: data.map( d => ( {
        date: d.date,
        value: d.total_donors - d.recurring_donors,
        offset: d.recurring_donors - 3
      } ) )
    }
  };
  const donorBarSeriesMaxValue = _.max(
    _.flatten(
      _.map(
        donorBarSeries,
        s => _.map( s.data, d => d.value + ( d.offset || 0 ) )
      )
    )
  );
  return (
    <div className="Donors">
      <h4>
        <a name="donors" href="#donors">
          <span>{I18n.t( "views.stats.year.donors" )}</span>
        </a>
      </h4>
      {/*
      <DateHistogram
        series={donationSeries}
        legendPosition="nw"
        tickFormatLeft={d3.format( "$.2s" )}
        guides={[
          { axis: "y", value: 20000, label: "Infrastructure is about $20k / month" }
        ]}
      />
      */}
      <DateHistogram
        series={donorBarSeries}
        legendPosition="translate(50,10)"
        xExtent={[moment( `${year}-01-01` ), moment( `${year + 1}-01-01` )]}
        yExtent={[0, donorBarSeriesMaxValue + ( 0.15 * donorBarSeriesMaxValue )]}
        margin={{
          top: 0,
          right: 0,
          bottom: 20,
          left: 30
        }}
        guides={[
          {
            axis: "y",
            value: 1000,
            label: I18n.t( "views.stats.year.donors_guide_label_our_goal_is_1000" ),
            dasharray: 2,
            color: COLORS.mediumGray,
            offset: 15
          }
        ]}
      />
      {/*
        <DateHistogram
          series={donorSeries}
          legendPosition="nw"
          guides={[
            { axis: "y", value: 1000, label: "Our goal is 1000 monthly supporters" }
          ]}
        />
      */}
    </div>
  );
};

Donations.propTypes = {
  year: PropTypes.number,
  data: PropTypes.array
};

export default Donations;
