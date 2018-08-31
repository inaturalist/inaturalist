import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import Util from "../models/util";
import SplitTaxon from "../../shared/components/split_taxon";

class ProjectSpecies extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  componentDidMount( ) {
    this.reloadData( );
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.project.id !== this.props.project.id ) {
      this.reloadData( );
    }
  }

  reloadData( ) {
    /* eslint no-console: 0 */
    Util.nodeApiFetch(
      `observations/species_counts?per_page=6&project_id=${this.props.project.id}&ttl=600&locale=` + I18n.locale ).
      then( json => {
        this.props.updateState( { speciesStats: { all: json } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch(
      `observations/species_counts?per_page=4&project_id=${this.props.project.id}&threatened=true&ttl=600&locale=` + I18n.locale ).
      then( json => {
        this.props.updateState( { speciesStats: { threatened: json } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch(
      `observations/species_counts?per_page=4&project_id=${this.props.project.id}&introduced=true&ttl=600&locale=` + I18n.locale ).
      then( json => {
        this.props.updateState( { speciesStats: { introduced: json } } );
      } ).catch( e => console.log( e ) );
  }

  render( ) {
    let species;
    if ( this.props.speciesStats.all ) {
      species = (
        <div>
          <div className="heading">{ I18n.t( "most_observed_species" ) }</div>
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
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <SplitTaxon taxon={ r.taxon } />
                  <span className="count">
                    { I18n.t( "x_observations_", { count: r.count } ) }
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
          <div className="heading">{ I18n.t( "most_observed_introduced_species" ) }</div>
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
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <SplitTaxon taxon={ r.taxon } />
                  <span className="count">
                    { I18n.t( "x_observations_", { count: r.count } ) }
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
          <div className="heading">{ I18n.t( "most_observed_threatened_species" ) }</div>
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
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <SplitTaxon taxon={ r.taxon } />
                  <span className="count">
                    { I18n.t( "x_observations_", { count: r.count } ) }
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

ProjectSpecies.propTypes = {
  project: PropTypes.object,
  speciesStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ProjectSpecies;
