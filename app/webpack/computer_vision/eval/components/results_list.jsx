import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import SplitTaxon from "../../../shared/components/split_taxon";
import util from "../../../observations/show/util";

/* eslint jsx-a11y/click-events-have-key-events: 0 */
/* eslint jsx-a11y/no-static-element-interactions: 0 */

class ResultsList extends Component {
  constructor( ) {
    super( );
    this.setViewableTaxa = this.setViewableTaxa.bind( this );
    this.taxon = this.taxon.bind( this );
    this.state = {
      viewableTaxa: []
    };
  }

  componentDidMount( ) {
    this.setViewableTaxa( );
  }

  componentDidUpdate( prevProps ) {
    if ( !_.isEqual( _.map( prevProps.taxa, "id" ), _.map( this.props.taxa, "id" ) ) ) {
      this.setViewableTaxa( );
    }
  }

  setViewableTaxa( ) {
    // const parentIDs = _.flatten( _.uniq( _.map( this.props.taxa, "parent_id" ) ) );
    // const leaves = _.filter( this.props.taxa, t => !_.includes( parentIDs, t.taxon_id ) );
    const firstLeaf = _.first( _.reverse( _.sortBy( this.props.taxa, "normalized_combined_score" ) ) );
    this.setState( {
      viewableTaxa: _.filter(
        this.props.taxa,
        t => t.normalized_combined_score >= firstLeaf.normalized_combined_score * 0.001
      ).slice( 0, 10 )
    } );
  }

  taxon( result, options = { } ) {
    const { setHoverResult, hoverResult } = this.props;
    const taxon = result.taxon || result;
    const taxonImageTag = util.taxonImage( taxon );
    const subtitles = [I18n.t( "visually_similar" )];
    if ( result.geo_score > result.geo_threshold ) {
      subtitles.push( I18n.t( "expected_nearby" ) );
    }
    const isInFocus = hoverResult && result
      && ( ( result.taxon_id === hoverResult.taxon_id )
        || ( result.left >= hoverResult.left
          && result.right <= hoverResult.right
          && result.right === result.left + 1 ) );
    return (
      <div
        key={`result-${taxon.id}`}
        className={
          `result${options.commonAncestor ? " common-ancestor" : ""}${isInFocus ? " focus" : ""}`
        }
        onMouseOver={() => setHoverResult( result )}
        onFocus={() => setHoverResult( result )}
      >
        <div className="photo">
          <a
            href={`/taxa/${taxon.id}`}
            target="_blank"
            rel="noopener noreferrer"
          >
            {taxonImageTag}
          </a>
        </div>
        <div className="name">
          <div>
            <SplitTaxon
              taxon={taxon}
              url={`/taxa/${taxon.id}`}
              noParens
              target="_blank"
              user={this.props.config.currentUser}
              showMemberGroup
              noInactive
            />
            <span className="subtitle">
              {subtitles.join( "/" )}
            </span>
          </div>
        </div>
        <div className="score">
          {_.round( result.vision_score, 3 ) || "N/A"}
        </div>
        <div className="score">
          {_.round( result.normalized_combined_score, 3 )}
        </div>
        <div className="score">
          {_.round( result.geo_score, 3 )}
        </div>
        <div className="score">
          {_.round( result.geo_threshold, 3 )}
        </div>
      </div>
    );
  }

  render( ) {
    return (
      <div id="ResultsList">
        <div>
          <div className="header">
            <div className="spacer" />
            <div className="score">
              Vision
            </div>
            <div className="score">
              Combined
            </div>
            <div className="score">
              Geo
            </div>
            <div className="score">
              Threshold
            </div>
          </div>
          { !_.isEmpty( this.props.commonAncestor ) && (
            this.taxon( this.props.commonAncestor, { commonAncestor: true } )
          ) }
          { this.state.viewableTaxa.map( this.taxon ) }
        </div>
      </div>
    );
  }
}

ResultsList.propTypes = {
  taxa: PropTypes.array,
  config: PropTypes.object,
  commonAncestor: PropTypes.object,
  setHoverResult: PropTypes.func,
  hoverResult: PropTypes.object
};

export default ResultsList;
