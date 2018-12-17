import React from "react";
import PropTypes from "prop-types";
import moment from "moment";
import _ from "lodash";
import inatjs from "inaturalistjs";
import ObservationsGrid from "./observations_grid";
import DateHistogram from "./date_histogram";

class NewSpecies extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      focusYear: null,
      focusMonth: null,
      observations: [],
      showAccumulation: false,
      loadingObservations: false,
      totalSpeciesIDsForMonth: 0
    };
  }

  getObservationsOfSpecies( speciesIDs, year, month ) {
    const { user } = this.props;
    const params = {
      place_id: "any",
      verifiable: true,
      taxon_ids: speciesIDs.slice( 0, 200 ).join( "," ),
      order: "desc",
      order_by: "votes",
      locale: I18n.locale,
      preferred_place_id: PREFERRED_PLACE ? PREFERRED_PLACE.id : null,
      per_page: 100,
      created_d1: moment( `${year}-${month}-10` ).startOf( "month" ).format( "YYYY-MM-DD" ),
      created_d2: moment( `${year}-${month}-10` ).endOf( "month" ).format( "YYYY-MM-DD" )
    };
    if ( user ) {
      params.user_id = user.id;
    }
    this.setState( {
      observations: [],
      loadingObservations: true,
      focusYear: year,
      focusMonth: month,
      totalSpeciesIDsForMonth: speciesIDs.length
    } );
    inatjs.observations.search( params )
      .then( r => {
        const observations = _.uniqBy( r.results, o => o.taxon.min_species_ancestry );
        this.setState( { observations, loadingObservations: false } );
      } )
      .catch( ( ) => {
        this.setState( { observations: [], loadingObservations: false } );
      } );
  }

  render( ) {
    const {
      accumulation,
      year,
      currentUser
    } = this.props;
    const {
      showAccumulation,
      loadingObservations,
      observations,
      focusYear,
      focusMonth,
      totalSpeciesIDsForMonth
    } = this.state;
    const series = {};
    const data = accumulation.map( i => i );
    data.push( {
      date: `${year + 1}-01-01`,
      accumulated_species_count: 0,
      novel_species_ids: []
    } );
    const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
    if ( showAccumulation ) {
      series.accumulated = {
        title: I18n.t( "running_total" ),
        data: _.map( data, i => ( {
          date: i.date,
          value: i.accumulated_species_count
        } ) ),
        style: "bar",
        color: grayColor,
        label: d => `<strong>${
          moment( d.date ).add( 2, "days" ).format( "MMMM YYYY" )
        }</strong>: ${I18n.t( "x_species", { count: I18n.toNumber( d.value, { precision: 0 } ) } )}`
      };
    }
    series.novel = {
      title: I18n.t( "newly_added" ),
      data: _.map( data, i => ( {
        date: i.date,
        value: i.novel_species_ids.length,
        novel_species_ids: i.novel_species_ids,
        offset: showAccumulation ? i.accumulated_species_count - i.novel_species_ids.length : 0
      } ) ),
      style: "bar",
      label: d => `<strong>${
        moment( d.date ).add( 2, "days" ).format( "MMMM YYYY" )
      }</strong>: ${I18n.t( "x_new_species", { count: I18n.toNumber( d.value, { precision: 0 } ) } )}`
    };
    return (
      <div className="NewSpecies">
        <h3><span>{ I18n.t( "newly_added_species" ) }</span></h3>
        <p
          className="text-muted"
          dangerouslySetInnerHTML={{ __html: I18n.t( "views.stats.year.new_species_desc_html", { site_name: SITE.name } ) }}
        />
        <DateHistogram
          id="accumulation"
          series={series}
          legendPosition="nw"
          showContext
          onClick={d => {
            if ( d.seriesName === "accumulated" ) {
              return false;
            }
            const date = moment( d.date ).add( 2, "days" );
            this.getObservationsOfSpecies( d.novel_species_ids, date.year( ), date.month( ) + 1 );
            return false;
          }}
          xExtent={[new Date( `${year}-01-01` ), new Date( `${year}-12-31` )]}
        />
        <div className="controls text-center stacked">
          { showAccumulation ? (
            <button
              type="button"
              className="btn btn-sm btn-default"
              onClick={( ) => this.setState( { showAccumulation: false } )}
            >
              { I18n.t( "hide_running_total" ) }
            </button>
          ) : (
            <button
              type="button"
              className="btn btn-sm btn-default"
              onClick={( ) => this.setState( { showAccumulation: true } )}
            >
              { I18n.t( "show_running_total" ) }
            </button>
          ) }
        </div>
        <div className="new-species-observations">
          { loadingObservations && (
            <div className="text-center">
              <div className="big loading_spinner" />
            </div>
          ) }
          { observations && observations.length > 0 && (
            <h4>
              <span>
                { observations.length < totalSpeciesIDsForMonth ? (
                  I18n.t( "new_species_added_in_interval_x_of_y", {
                    interval: moment( `${focusYear}-${focusMonth}-10` ).format( "MMMM YYYY" ),
                    x: observations.length,
                    y: totalSpeciesIDsForMonth
                  } )
                ) : (
                  I18n.t( "new_species_added_in_interval", {
                    interval: moment( `${focusYear}-${focusMonth}-10` ).format( "MMMM YYYY" )
                  } )
                ) }
              </span>
            </h4>
          ) }
          <ObservationsGrid
            observations={observations}
            identifier="NewSpeciesObservations"
            columns={6}
            max={observations.length}
            user={currentUser}
          />
        </div>
      </div>
    );
  }
}

NewSpecies.propTypes = {
  accumulation: PropTypes.array,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  year: PropTypes.number
};

export default NewSpecies;
