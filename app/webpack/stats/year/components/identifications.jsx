import React from "react";
import _ from "lodash";
import moment from "moment";
import { Row, Col } from "react-bootstrap";
import UserWithIcon from "../../../observations/show/components/user_with_icon";
import DateHistogram from "./date_histogram";
import PieChartForIconicTaxonCounts from "./pie_chart_for_iconic_taxon_counts";

const Identifications = ( { data, user } ) => {
  if ( _.isEmpty( data ) ) {
    return <div></div>;
  }
  const series = {};
  const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
  if ( data.month_histogram ) {
    series.month = {
      title: I18n.t( "per_month" ),
      data: _.map( data.month_histogram, ( value, date ) => ( { date, value } ) ),
      style: "bar",
      color: grayColor,
      label: d => `<strong>${moment( d.date ).format( "MMMM" )}</strong>: ${d.value}`
    };
  }
  if ( data.week_histogram ) {
    series.week = {
      title: I18n.t( "per_week" ),
      data: _.map( data.week_histogram, ( value, date ) => ( { date, value } ) ),
      color: "rgba( 168, 204, 9, 0.2 )",
      style: "bar",
      label: d => `<strong>${I18n.t( "week_of_date", { date: moment( d.date ).format( "LL" ) } )}</strong>: ${d.value}`
    };
  }
  if ( data.day_histogram ) {
    series.day = {
      title: "Per Day",
      data: _.map( data.day_histogram, ( value, date ) => ( { date, value } ) ),
      color: "#74ac00"
    };
  }
  return (
    <div className="Identifications">
      <Row>
        <Col xs={ 12 }>
          <h3><span>{ I18n.t( "ids_made_for_others" ) }</span></h3>
          <DateHistogram
            series={ series }
            tickFormatBottom={ d => moment( d ).format( "MMM D" ) }
            onClick={ d => {
              let url = "/identifications?for=others&current=true";
              const d1 = moment( d.date ).format( "YYYY-MM-DD" );
              let d2;
              if ( d.seriesName === "month" ) {
                d2 = moment( d.date ).endOf( "month" ).add( 1, "day" ).format( "YYYY-MM-DD" );
              } else if ( d.seriesName === "week" ) {
                d2 = moment( d.date ).add( 8, "days" ).format( "YYYY-MM-DD" );
              } else {
                d2 = moment( d.date ).add( 1, "day" ).format( "YYYY-MM-DD" );
              }
              url += `&d1=${d1}&d2=${d2}`;
              if ( user ) {
                url += `&user_id=${user.login}`;
              }
              window.open( url, "_blank" );
            } }
          />
        </Col>
      </Row>
      { user && ( data.users_helped || data.users_who_helped ) ? (
        <Row>
          <Col xs={ 4 }>
            { data.users_helped ? (
              <div className="idents-users-helped">
                <h3><span>{ I18n.t( "who_user_helped_the_most", { user: user.login } ) }</span></h3>
                { data.users_helped.map( d => (
                  <UserWithIcon
                    user={ Object.assign( {}, d.user, { icon_url: d.user.icon } ) }
                    subtitle={ I18n.t( "x_identifications", { count: d.count } ) }
                    subtitleIconClass=" "
                    key={ `idents-users-helped-${d.user.id}` }
                  />
                ) ) }
              </div>
            ) : null }
          </Col>
          <Col xs={ 4 }>
            <h3><span>{ I18n.t( "ids_by_taxon" ) }</span></h3>
            <PieChartForIconicTaxonCounts
              data={ data.iconic_taxon_counts }
              donutWidth={ 20 }
              labelForDatum={ d => {
                const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
                const percent = _.round( degrees / 360 * 100, 2 );
                const value = I18n.t( "x_identifications", {
                  count: I18n.toNumber( d.value, { precision: 0 } )
                } );
                return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
              }}
            />
          </Col>
          <Col xs={ 4 }>
            { data.users_who_helped ? (
              <div className="idents-users-who-helped">
                <h3><span>{ I18n.t( "who_helped_user_the_most", { user: user.login } ) }</span></h3>
                { data.users_who_helped.map( d => (
                  <UserWithIcon
                    user={ Object.assign( {}, d.user, { icon_url: d.user.icon } ) }
                    subtitle={ I18n.t( "x_identifications", { count: d.count } ) }
                    subtitleIconClass=" "
                    key={ `idents-users-who-helped-${d.user.id}` }
                  />
                ) ) }
              </div>
            ) : null }
          </Col>
        </Row>
      ) : null }
    </div>
  );
};

Identifications.propTypes = {
  data: React.PropTypes.object,
  user: React.PropTypes.object
};

export default Identifications;
