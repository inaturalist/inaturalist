import React from "react";
import PropTypes from "prop-types";
import { OverlayTrigger, Popover } from "react-bootstrap";
import _ from "lodash";
import { urlForTaxon, RANK_LEVELS } from "../../taxa/shared/util";
import SplitTaxon from "./split_taxon";

const TaxonomicBranch = ( {
  taxon,
  allChildrenShown,
  toggleAllChildrenShown,
  currentUser,
  chooseTaxon,
  noHideable
} ) => {
  const branch = [];
  const currentTaxon = Object.assign( { }, taxon );
  if ( taxon ) {
    if ( taxon.ancestors ) {
      const ancestors = Object.assign( [], currentTaxon.ancestors );
      ancestors.push( currentTaxon );
      branch.push( Object.assign( {}, ancestors.shift( ) ) );
      let lastAncestor = branch[0];
      for ( let i = 0; i < ancestors.length; i++ ) {
        lastAncestor.children = lastAncestor.children || [];
        lastAncestor.children.push( Object.assign( {}, ancestors[i] ) );
        lastAncestor = lastAncestor.children[lastAncestor.children.length - 1];
      }
    } else {
      branch.push( taxon );
    }
  }
  const renderTaxonomy = taxa => (
    <ul className="plain taxonomy">
      { ( _.sortBy( taxa, t => [(100 - t.rank_level), t.name] ) || [] ).map( t => {
        let className = "";
        const isRoot = t.id === branch[0].id;
        const isTaxon = t.id === taxon.id;
        const isDescendant = t.ancestor_ids && t.ancestor_ids.indexOf( taxon.id ) >= 0;
        const shouldLinkToTaxon = !isRoot && !isTaxon;
        const isComplete = isTaxon && taxon.complete_rank && taxon.rank_level > RANK_LEVELS[taxon.complete_rank];
        const isHidable = isDescendant && ( t.rank === "hybrid" || !t.is_active || t.extinct );
        const numChildren = ( t.children || [] ).length;
        const numHidableChildren = _.filter( t.children || [], c => (
          c.rank === "hybrid" || !c.is_active || c.extinct
        ) ).length;
        const tabular = false;
        if ( isTaxon ) {
          className += "current";
        }
        if ( isRoot ) {
          className += " root";
        }
        if ( isComplete ) {
          className += " complete";
        }
        if ( isHidable ) {
          className += " hidable";
        }
        if ( numChildren <= 1 || allChildrenShown ) {
          className += " all-shown";
        }
        if ( tabular ) {
          className += " tabular";
        }
        return (
          <li key={`taxonomy-${t.id}`} className={ className }>
            <div className="row-content">
              <div className="name-row">
                <SplitTaxon
                  taxon={t}
                  url={shouldLinkToTaxon ? urlForTaxon( t ) : null}
                  forceRank
                  user={ currentUser }
                  onClick={ e => {
                    if ( !shouldLinkToTaxon ) return true;
                    if ( e.metaKey || e.ctrlKey ) return true;
                    e.preventDefault( );
                    chooseTaxon( t );
                    return false;
                  } }
                />
                { isComplete ? (
                  <div className="inlineblock taxonomy-complete-notice">
                    <div className="label-complete">
                      { I18n.t( `all_rank_added_to_the_database.${taxon.complete_rank || "species"}` ) }
                    </div>
                    <OverlayTrigger
                      container={ $( ".suggestions-detail" ).get( 0 ) }
                      trigger="click"
                      rootClose
                      placement="top"
                      animation={false}
                      overlay={
                        <Popover
                          id={ `complete-taxon-popover-${t.id}` }
                          className="complete-taxon-popover"
                          title={ I18n.t( "about_complete_taxa" ) }
                        >
                          { I18n.t( "views.taxa.show.complete_taxon_desc" ) }
                        </Popover>
                      }
                    >
                      <a
                        href={ urlForTaxon( t ) }
                        onClick={ e => {
                          e.preventDefault( );
                          return false;
                        }}
                      >
                        <i className="fa fa-info-circle"></i> { I18n.t( "info" ) }
                      </a>
                    </OverlayTrigger>
                    { noHideable || numChildren <= 1 || numHidableChildren === 0 ? null : (
                      <span>
                        <span className="text-muted">&bull;</span>
                        <a
                          href="#"
                          onClick={ e => {
                            e.preventDefault( );
                            toggleAllChildrenShown( );
                            return false;
                          }}
                        >
                          { allChildrenShown ? I18n.t( "hide_uncountable_species" ) : I18n.t( "show_uncountable_species" ) }
                        </a>
                      </span>
                    ) }
                  </div>
                ) : null }
              </div>
              { tabular && isTaxon ? (
                <div style={ { whiteSpace: "nowrap" } }>
                  { I18n.t( "observations" ) }
                </div>
              ) : null }
              { tabular && isDescendant ? (
                <div className={`text-${t.observations_count === 0 ? "default" : "success"} label-obs-count`}>
                  { t.observations_count === 0 ? t.observations_count : (
                    <a href={`/observations?taxon_id=${t.id}&place_id=any`}>{ t.observations_count }</a>
                  ) }
                </div>
              ) : null }
            </div>
            { t.children && t.children.length > 0 ? renderTaxonomy( t.children ) : null }
          </li>
        );
      } ) }
    </ul>
  );

  return (
    <div className="TaxonomicBranch">
      { renderTaxonomy( branch ) }
    </div>
  );
};

TaxonomicBranch.propTypes = {
  taxon: PropTypes.object,
  allChildrenShown: PropTypes.bool,
  toggleAllChildrenShown: PropTypes.func,
  currentUser: PropTypes.object,
  chooseTaxon: PropTypes.func,
  noHideable: PropTypes.bool
};

TaxonomicBranch.defaultProps = {
  noHideable: false
};

export default TaxonomicBranch;
