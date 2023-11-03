import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import * as d3 from "d3";
import { COLORS } from "../../../shared/util";
import PieChart from "./pie_chart";
import PieChartForIconicTaxonCounts from "./pie_chart_for_iconic_taxon_counts";

/* global DEFAULT_SITE_ID */

const Summary = ( {
  data,
  user,
  currentUser,
  year,
  site
} ) => {
  const pieMargin = {
    top: 0, bottom: 130, left: 0, right: 0
  };
  const donutWidth = 20;
  let baseObsUrl = `/observations?d1=${year}-01-01&d2=${year}-12-31`;
  if ( user ) {
    baseObsUrl += `&user_id=${user.login}`;
  }
  if ( site && site.id !== DEFAULT_SITE_ID ) {
    if ( site.place_id ) {
      baseObsUrl += `&place_id=${site.place_id}`;
    } else {
      baseObsUrl += `&site_id=${site.id}`;
    }
  } else {
    baseObsUrl += "&place_id=any";
  }
  const hasDataForPeopleChart = data.users && data.users.obs_and_id_activity_counts;
  const colWidth = hasDataForPeopleChart ? 3 : 4;
  return (
    <Row className="Summary">
      <Col sm={12} md={colWidth}>
        { data.observations.quality_grade_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={{
                __html: I18n.t( "x_observations_html", {
                  count: I18n.toNumber(
                    ( data.observations.quality_grade_counts.research || 0 )
                    + ( data.observations.quality_grade_counts.needs_id || 0 ),
                    { precision: 0 }
                  )
                } )
              }}
            />
            <PieChart
              data={[
                {
                  label: _.upperFirst( I18n.t( "casual" ) ),
                  value: data.observations.quality_grade_counts.casual,
                  color: "#aaaaaa",
                  qualityGrade: "casual"
                },
                {
                  label: _.upperFirst( I18n.t( "needs_id" ) ),
                  value: data.observations.quality_grade_counts.needs_id,
                  color: COLORS.needsIdYellow,
                  qualityGrade: "needs_id"
                },
                {
                  label: _.upperFirst( I18n.t( "research" ) ),
                  value: data.observations.quality_grade_counts.research,
                  color: COLORS.inatGreenLight,
                  qualityGrade: "research"
                }
              ]}
              legendColumnWidth={50}
              margin={pieMargin}
              donutWidth={donutWidth}
              onClick={( _clickEvent, d ) => {
                let url = `${baseObsUrl}&quality_grade=${d.data.qualityGrade}`;
                if ( d.data.qualityGrade === "casual" ) {
                  url += "&verifiable=any";
                }
                window.open( url, "_blank" );
              }}
            />
          </div>
        ) : null }
      </Col>
      <Col sm={12} md={colWidth}>
        { data.taxa && data.taxa.iconic_taxa_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={{
                __html: I18n.t( "x_species_html", {
                  count: I18n.toNumber(
                    (
                      data.taxa.leaf_taxa_count
                    ),
                    { precision: 0 }
                  )
                } )
              }}
            />
            <PieChartForIconicTaxonCounts
              data={data.taxa.iconic_taxa_counts}
              margin={pieMargin}
              donutWidth={donutWidth}
              user={user}
              site={site}
              year={year}
              labelForDatum={d => {
                const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
                const percent = _.round( degrees / 360 * 100, 2 );
                const value = I18n.t( "x_observations", {
                  count: I18n.toNumber( d.value, { precision: 0 } )
                } );
                return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
              }}
            />
          </div>
        ) : null }
      </Col>
      <Col sm={12} md={colWidth}>
        { data.identifications && data.identifications.category_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={{
                __html: I18n.t( "x_identifications_html", {
                  count: I18n.toNumber(
                    _.sum( _.map( data.identifications.category_counts, v => v ) ),
                    { precision: 0 }
                  )
                } )
              }}
            />
            <PieChart
              data={[
                {
                  label: I18n.t( "improving" ),
                  value: data.identifications.category_counts.improving,
                  color: COLORS.inatGreen,
                  category: "improving"
                },
                {
                  label: I18n.t( "supporting" ),
                  value: data.identifications.category_counts.supporting,
                  color: COLORS.inatGreenLight,
                  category: "supporting"
                },
                {
                  label: I18n.t( "leading" ),
                  value: data.identifications.category_counts.leading,
                  color: COLORS.needsIdYellow,
                  category: "leading"
                },
                {
                  label: I18n.t( "maverick" ),
                  value: data.identifications.category_counts.maverick,
                  color: COLORS.failRed,
                  category: "maverick"
                }
              ]}
              legendColumns={2}
              legendColumnWidth={100}
              margin={pieMargin}
              donutWidth={donutWidth}
              onClick={currentUser && currentUser.id ? ( _clickEvent, d ) => {
                let url = `/identifications?for=others&current=true&category=${d.data.category}&d1=${year}-01-01&d2=${year}-12-31`;
                if ( user ) {
                  url += `&user_id=${user.login}`;
                }
                window.open( url, "_blank" );
              } : null}
            />
          </div>
        ) : null }
      </Col>
      <Col sm={12} md={colWidth}>
        { hasDataForPeopleChart ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={{
                __html: I18n.t( "x_people_html", {
                  count: I18n.toNumber(
                    data.users.obs_and_id_activity_counts.observed_or_identified_count,
                    { precision: 0 }
                  )
                } )
              }}
            />
            <PieChart
              data={[
                {
                  label: I18n.t( "views.stats.year.added_only_observations" ),
                  //value: data.users.obs_and_id_activity_counts.only_observed_count,
                  value: 100,
                  color: d3.color( COLORS.iconic.Aves ).brighter( 0.5 ),
                  chartDisplayOrder: 0
                },
                {
                  label: I18n.t( "views.stats.year.added_only_identifications" ),
                  //value: data.users.obs_and_id_activity_counts.only_identified_count,
                  value: 2,
                  color: d3.color( COLORS.iconic.Insecta ).brighter( ),
                  chartDisplayOrder: 2
                },
                {
                  label: I18n.t( "views.stats.year.added_observations_and_identifications" ),
                  //value: data.users.obs_and_id_activity_counts.observed_and_identified_count,
                  value: 10,
                  color: COLORS.inatGreenLight,
                  chartDisplayOrder: 1
                }
              ]}
              legendColumnWidth={230}
              margin={pieMargin}
              donutWidth={donutWidth}
            />
          </div>
        ) : null }
      </Col>
    </Row>
  );
};

Summary.propTypes = {
  data: PropTypes.object,
  year: PropTypes.number,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  site: PropTypes.object
};

export default Summary;
