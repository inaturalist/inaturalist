import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import moment from "moment";
import UserWithIcon from "../../../observations/show/components/user_with_icon";
import DateHistogram from "../../../shared/components/date_histogram";
import PieChartForIconicTaxonCounts from "./pie_chart_for_iconic_taxon_counts";

const Identifications = ( {
  data,
  user,
  currentUser,
  year
} ) => {
  if ( _.isEmpty( data ) ) {
    return <div />;
  }
  const series = {};
  const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
  if ( data.month_histogram ) {
    series.month = {
      title: I18n.t( "per_month" ),
      data: _.map( data.month_histogram, ( value, date ) => ( { date, value } ) ),
      style: "bar",
      color: grayColor,
      label: d => I18n.t( "bold_label_colon_value_html", {
        label: moment( d.date ).add( 2, "days" ).format( "MMMM" ),
        value: I18n.t( "x_identifications", { count: I18n.toNumber( d.value, { precision: 0 } ) } )
      } )
    };
  }
  if ( data.week_histogram ) {
    series.week = {
      title: I18n.t( "per_week" ),
      data: _.map( data.week_histogram, ( value, date ) => ( { date, value } ) ),
      color: "rgba( 168, 204, 9, 0.2 )",
      style: "bar",
      label: d => I18n.t( "bold_label_colon_value_html", {
        label: I18n.t( "week_of_date", { date: moment( d.date ).format( "LL" ) } ),
        value: I18n.t( "x_identifications", { count: I18n.toNumber( d.value, { precision: 0 } ) } )
      } )
    };
  }
  if ( data.day_histogram ) {
    series.day = {
      title: I18n.t( "per_day" ),
      data: _.map( data.day_histogram, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00",
      label: d => I18n.t( "bold_label_colon_value_html", {
        label: moment( d.date ).format( "ll" ),
        value: I18n.t( "x_identifications", { count: I18n.toNumber( d.value, { precision: 0 } ) } )
      } )
    };
  }
  return (
    <div className="Identifications">
      { series && series.month && series.month.data.length > 0 && (
        <div className="flex-row">
          <div>
            <h3>
              <a name="ids-for-others" href="#ids-for-others">
                <span>{ I18n.t( "ids_made_for_others" ) }</span>
              </a>
            </h3>
            <DateHistogram
              series={series}
              tickFormatBottom={d => moment( d ).format( "MMM D" )}
              onClick={currentUser && currentUser.id ? ( _clickEvent, d ) => {
                let url = "/identifications?for=others&current=true";
                const d1 = moment( d.date ).format( "YYYY-MM-DD" );
                let d2;
                if ( d.seriesName === "month" ) {
                  d2 = moment( d.date ).add( 2, "days" ).endOf( "month" ).format( "YYYY-MM-DD" );
                } else if ( d.seriesName === "week" ) {
                  d2 = moment( d.date ).endOf( "week" ).add( 1, "day" ).format( "YYYY-MM-DD" );
                } else {
                  d2 = moment( d.date ).format( "YYYY-MM-DD" );
                }
                url += `&d1=${d1}&d2=${d2}`;
                if ( user ) {
                  url += `&user_id=${user.login}`;
                }
                window.open( url, "_blank" );
              } : null}
              margin={{ left: 60 }}
            />
          </div>
        </div>
      ) }
      { user && ( data.users_helped || data.users_who_helped ) ? (
        <div className="flex-row helped-row">
          { data.users_helped && data.users_helped.length > 0 ? (
            <div className="idents-users-helped">
              <h3>
                <a name="helped" href="#helped">
                  <span>{ I18n.t( "who_user_helped_the_most", { user: user.login } ) }</span>
                </a>
              </h3>
              { data.users_helped.map( d => (
                <UserWithIcon
                  user={Object.assign( {}, d.user, { icon_url: d.user.icon } )}
                  subtitle={I18n.t( "x_identifications", { count: d.count } )}
                  skipSubtitleLink
                  subtitleIconClass=" "
                  key={`idents-users-helped-${d.user.id}`}
                />
              ) ) }
              { data.total_users_helped && data.total_ids_given && (
                <p
                  className="text-muted"
                  dangerouslySetInnerHTML={{
                    __html: I18n.t( "user_helped_x_people_with_y_ids_html", {
                      user: user.login,
                      x: I18n.toNumber( data.total_users_helped, { precision: 0 } ),
                      y: I18n.toNumber( data.total_ids_given, { precision: 0 } )
                    } )
                  }}
                />
              ) }
            </div>
          ) : null }
          { data.iconic_taxon_counts && _.find( data.iconic_taxon_counts, v => v > 0 ) > 0 && (
            <div>
              <h3>
                <a name="ids-by-taxon" href="#ids-by-taxon">
                  <span>{ I18n.t( "ids_by_taxon" ) }</span>
                </a>
              </h3>
              <PieChartForIconicTaxonCounts
                year={year}
                data={data.iconic_taxon_counts}
                donutWidth={20}
                labelForDatum={d => {
                  const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
                  const percent = _.round( degrees / 360 * 100, 2 );
                  const value = I18n.t( "x_identifications", {
                    count: I18n.toNumber( d.value, { precision: 0 } )
                  } );
                  return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
                }}
              />
            </div>
          ) }
          { data.users_who_helped ? (
            <div className="idents-users-who-helped">
              <h3>
                <a name="helpers" href="#helpers">
                  <span>{ I18n.t( "who_helped_user_the_most", { user: user.login } ) }</span>
                </a>
              </h3>
              { data.users_who_helped.map( d => (
                <UserWithIcon
                  user={Object.assign( {}, d.user, { icon_url: d.user.icon } )}
                  subtitle={I18n.t( "x_identifications", { count: d.count } )}
                  skipSubtitleLink
                  subtitleIconClass=" "
                  key={`idents-users-who-helped-${d.user.id}`}
                />
              ) ) }
              { data.total_users_who_helped && data.total_ids_received && (
                <p
                  className="text-muted"
                  dangerouslySetInnerHTML={{
                    __html: I18n.t( "x_people_helped_user_with_y_ids_html", {
                      user: user.login,
                      x: I18n.toNumber( data.total_users_who_helped, { precision: 0 } ),
                      y: I18n.toNumber( data.total_ids_received, { precision: 0 } )
                    } )
                  }}
                />
              ) }
            </div>
          ) : null }
        </div>
      ) : null }
    </div>
  );
};

Identifications.propTypes = {
  data: PropTypes.object,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  year: PropTypes.number
};

export default Identifications;
