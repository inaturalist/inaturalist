import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import Util from "../../project_slideshow/models/util";
import SplitTaxon from "../../shared/components/split_taxon";

class ResultsSpecies extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  componentDidMount( ) {
    this.reloadData( );
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.searchParams !== this.props.searchParams ) {
      this.reloadData( );
    }
  }

  reloadData( ) {
    /* eslint no-console: 0 */
    Util.nodeApiFetch(
      `observations/species_counts?per_page=6&${$.param( this.props.searchParams )}&ttl=600` ).
      then( json => {
        this.props.updateState( { speciesStats: { all: json } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch(
      `observations/species_counts?per_page=4&${$.param( this.props.searchParams )}&threatened=true&ttl=600` ).
      then( json => {
        this.props.updateState( { speciesStats: { threatened: json } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch(
      `observations/species_counts?per_page=4&${$.param( this.props.searchParams )}&introduced=true&ttl=600` ).
      then( json => {
        this.props.updateState( { speciesStats: { introduced: json } } );
      } ).catch( e => console.log( e ) );
  }

  render( ) {
    let species;
    if ( this.props.speciesStats.all ) {
      species = (
        <div>
          <div className="heading">Most Observed Species</div>
          { _.map( this.props.speciesStats.all.results, r => {
            let style;
            let placeholder;
            let prefetch;
            if ( r.taxon.default_photo ) {
              const photo = r.taxon.default_photo.medium_url;
              style = { backgroundImage: `url('${photo}')` };
              prefetch = ( <link rel="prefetch" href={ photo } /> );
            } else {
              placeholder = (
                <i className={ `icon icon-iconic-${r.taxon.iconic_taxon_name.toLowerCase( )}` } />
              );
            }
            return (
              <div key={ `species${r.taxon.id}` } className="species">
                { prefetch }
                <a href={ `/taxa/${r.taxon.id}`}>
                  <div className="image" style={ style }>
                    { placeholder }
                  </div>
                </a>
                <div className="meta">
                  <SplitTaxon taxon={ r.taxon } url={ `/taxa/${r.taxon.id}` } />
                  <span className="count">
                    <a href={ `/observations?verifiable=any&${$.param( Object.assign( { }, this.props.searchParams, { taxon_id: r.taxon.id } ) )}`}>
                      { I18n.t( "x_observations_", { count: r.count } ) }
                    </a>
                  </span>
                </div>
              </div>
            );
          } ) }
        </div>
      );
    }
    let introduced;
    if ( this.props.speciesStats.introduced ) {
      introduced = (
        <div>
          <div className="heading">Most Observed Introduced Species</div>
          { _.map( this.props.speciesStats.introduced.results, r => {
            let style;
            let placeholder;
            let prefetch;
            if ( r.taxon.default_photo ) {
              const photo = r.taxon.default_photo.medium_url;
              style = { backgroundImage: `url('${photo}')` };
              prefetch = ( <link rel="prefetch" href={ photo } /> );
            } else {
              placeholder = (
                <i className={ `icon icon-iconic-${r.taxon.iconic_taxon_name.toLowerCase( )}` } />
              );
            }
            return (
              <div key={ `introduced${r.taxon.id}` } className="species">
                { prefetch }
                <a href={ `/taxa/${r.taxon.id}`}>
                  <div className="image" style={ style }>{ placeholder }</div>
                </a>
                <div className="meta">
                  <SplitTaxon taxon={ r.taxon } url={ `/taxa/${r.taxon.id}` } />
                  <span className="count">
                    <a href={ `/observations?verifiable=any&${$.param( Object.assign( { }, this.props.searchParams, { taxon_id: r.taxon.id } ) )}`}>
                      { I18n.t( "x_observations_", { count: r.count } ) }
                    </a>
                  </span>
                </div>
              </div>
            );
          } ) }
        </div>
      );
    }
    let threatened;
    if ( this.props.speciesStats.threatened ) {
      threatened = (
        <div>
          <div className="heading">Most Observed Threatened Species</div>
          { _.map( this.props.speciesStats.threatened.results, r => {
            let style;
            let placeholder;
            let prefetch;
            if ( r.taxon.default_photo ) {
              const photo = r.taxon.default_photo.medium_url;
              style = { backgroundImage: `url('${photo}')` };
              prefetch = ( <link rel="prefetch" href={ photo } /> );
            } else {
              placeholder = (
                <i className={ `icon icon-iconic-${r.taxon.iconic_taxon_name.toLowerCase( )}` } />
              );
            }
            return (
              <div key={ `threatened${r.taxon.id}` } className="species">
                { prefetch }
                <a href={ `/taxa/${r.taxon.id}`}>
                  <div className="image" style={ style }>{ placeholder }</div>
                </a>
                <div className="meta">
                  <SplitTaxon taxon={ r.taxon } url={ `/taxa/${r.taxon.id}` } />
                  <span className="count">
                    <a href={ `/observations?verifiable=any&${$.param( Object.assign( { }, this.props.searchParams, { taxon_id: r.taxon.id } ) )}`}>
                      { I18n.t( "x_observations_", { count: r.count } ) }
                    </a>
                  </span>
                </div>
              </div>
            );
          } ) }
        </div>
      );
    }
    return (
      <div className="slide row-fluid species-slide">
        <div className="col-md-12 top">
          { species }
        </div>
        <div className="col-md-6 bottom-half">
          { introduced }
        </div>
        <div className="col-md-6 bottom-half">
          { threatened }
        </div>
      </div>
    );
  }
}

ResultsSpecies.propTypes = {
  searchParams: PropTypes.object,
  speciesStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ResultsSpecies;
