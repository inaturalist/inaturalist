import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Modal, Button } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
/* global LIFE_TAXON */
/* global SITE */

class CommunityIDModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.renderTaxonomy = this.renderTaxonomy.bind( this );
    this.state = { hoverTaxon: null };
  }

  close( ) {
    this.props.setCommunityIDModalState( { show: false } );
  }

  renderTaxonomy( currentTaxon, depth = 0 ) {
    let rows = [];
    const isLife = !currentTaxon;
    let sortedBranch;
    if ( isLife ) {
      sortedBranch = [LIFE_TAXON];
    } else {
      sortedBranch = _.reverse( _.sortBy( this.children[currentTaxon.id], t => (
        this.idTaxonAncestorCounts[t.id] || 0 ) ) );
      sortedBranch = _.filter( sortedBranch, t => ( t.id !== currentTaxon.id ) );
    }
    _.each( sortedBranch, taxon => {
      const idCount = this.idTaxonCounts[taxon.id] || 0;
      const usages = isLife ? this.currentIDs.length : (
        this.idTaxonAncestorCounts[taxon.id] || 0 );
      const disag = ( taxon.id === LIFE_TAXON.id ) ? 0 :
        _.filter( this.props.observation.identifications, i => (
          i.current && i.taxon.id !== taxon.id &&
          !_.includes( i.taxon.ancestor_ids, taxon.id ) &&
          !_.includes( taxon.ancestor_ids, i.taxon.id )
        ) ).length;
      const ancDisag = this.ancestorDisagreements[taxon.id] || 0;
      const taxonName = isLife ? LIFE_TAXON.default_name.name : (
        <SplitTaxon taxon={ taxon } url={ `/taxa/${taxon.id}` } forceRank user={ this.props.config.currentUser } /> );
      const denom = usages + disag + ancDisag;
      const score = _.round( usages / denom, 3 );
      let className;
      if ( this.props.observation.taxon.id === taxon.id ) {
        className = "current-id";
      } else if ( this.state.hoverTaxon ) {
        if ( this.state.hoverTaxon.id === taxon.id ) {
          // hover row
        } else if ( _.includes( this.state.hoverTaxon.ancestor_ids, taxon.id ) ) {
          className = "included";
        } else if ( _.includes( taxon.ancestor_ids, this.state.hoverTaxon.id ) ) {
          className = "included";
        } else {
          className = "excluded";
        }
      }
      if ( !_.includes( this.props.observation.taxon.ancestor_ids, taxon.id ) ) {
        className += " other-branch";
      }
      rows.push( (
        <tr key={ `id-breakdown-${taxon.id}` }
          className={ className }
          onMouseEnter={ ( ) => { this.setState( { hoverTaxon: taxon } ); } }
          onMouseLeave={ ( ) => { this.setState( { hoverTaxon: null } ); } }
        >
          <td
            className="taxon-cell"
            style={ { paddingLeft: `${( depth * 10 ) + 18}px` } }
          >{ taxonName}</td>
          <td>{ idCount }</td>
          <td>{ usages }</td>
          <td>{ disag }</td>
          <td>{ ancDisag }</td>
          <td className="score">
            { usages }/({ usages }+{ disag }+{ ancDisag }={ denom }) = { score }
          </td>
        </tr>
      ) );
      const childRows = this.renderTaxonomy( taxon, depth + 1 );
      if ( childRows && childRows.length > 0 ) {
        rows = rows.concat( childRows );
      }
    } );
    return rows;
  }

  render( ) {
    const observation = this.props.observation;
    if ( !observation ) { return ( <div /> ); }
    let algorithmSummary;
    if ( observation.taxon ) {
      this.roots = { };
      this.children = { };
      this.currentIDs = [];
      this.idTaxonCounts = { };
      this.idTaxonAncestorCounts = { };
      this.ancestorDisagreements = { };
      const ancestorsUsed = { };
      _.each( observation.identifications, i => {
        if ( !i.current || !i.taxon ) { return; }
        this.currentIDs.push( i );
        this.idTaxonCounts[i.taxon.id] = this.idTaxonCounts[i.taxon.id] || 0;
        this.idTaxonCounts[i.taxon.id] += 1;
        const allAncestors = _.clone( i.taxon.ancestorTaxa || [] );
        allAncestors.push( i.taxon );
        _.each( ancestorsUsed, ( ancestorIDs, taxonID ) => {
          if ( i.taxon.id !== Number( taxonID ) && _.includes( ancestorIDs, i.taxon.id ) ) {
            this.ancestorDisagreements[taxonID] = this.ancestorDisagreements[taxonID] || 0;
            this.ancestorDisagreements[taxonID] += 1;
          }
        } );
        let lastTaxon;
        _.each( allAncestors, t => {
          this.idTaxonAncestorCounts[t.id] = this.idTaxonAncestorCounts[t.id] || 0;
          this.idTaxonAncestorCounts[t.id] += 1;
          ancestorsUsed[t.id] = t.ancestor_ids;
          if ( !lastTaxon ) {
            this.roots[t.id] = t;
          } else {
            this.children[lastTaxon.id] = this.children[lastTaxon.id] || {};
            this.children[lastTaxon.id][t.id] = t;
          }
          lastTaxon = t;
        } );
      } );
      this.children[LIFE_TAXON.id] = this.roots;
      algorithmSummary = (
        <span>
          <h4>{ I18n.t( "views.observations.community_id.algorithm_summary" ) }</h4>
          <table className="table">
            <thead>
              <tr>
                <th>{ I18n.t( "taxon" ) }</th>
                <th>{ I18n.t( "views.observations.community_id.identification_count" ) }</th>
                <th>{ I18n.t( "views.observations.community_id.cumulative_count" ) }</th>
                <th>{ I18n.t( "views.observations.community_id.disagreement_count" ) }</th>
                <th>{ I18n.t( "views.observations.community_id.ancestor_disagreements" ) }</th>
                <th>{ I18n.t( "views.observations.community_id.score" ) }</th>
              </tr>
            </thead>
            <tbody>
              { this.renderTaxonomy( ) }
            </tbody>
          </table>
          <div className="legend">
            <span className="included">
              { I18n.t( "views.observations.community_id.agreement" ) }
            </span>
            <span className="excluded">
              { I18n.t( "views.observations.community_id.disagreement" ) }
            </span>
            <span className="other-branch">
              { I18n.t( "views.observations.community_id.below_cutoff" ) }
            </span>
          </div>
          <h4>Terms</h4>
          <dl>
            <dt>{ I18n.t( "views.observations.community_id.identification_count" ) }</dt>
            <dd>{ I18n.t( "views.observations.show.identification_count_desc" ) }</dd>
            <dt>{ I18n.t( "views.observations.community_id.cumulative_count" ) }</dt>
            <dd>{ I18n.t( "views.observations.show.cumulative_count_desc" ) }</dd>
            <dt>{ I18n.t( "views.observations.community_id.disagreement_count" ) }</dt>
            <dd>{ I18n.t( "views.observations.show.disagreement_count_desc" ) }</dd>
            <dt>{ I18n.t( "views.observations.community_id.ancestor_disagreements" ) }</dt>
            <dd>{ I18n.t( "views.observations.show.ancestor_disagreements_desc" ) }</dd>
            <dt>{ I18n.t( "views.observations.community_id.score" ) }</dt>
            <dd>{ I18n.t( "views.observations.show.score_desc" ) }</dd>
          </dl>
        </span>
      );
    }
    return (
      <Modal
        show={ this.props.show }
        className={ `CommunityIDModal ${observation.taxon ? "" : "no-taxon"}` }
        onHide={ this.close }
      >
        <Modal.Body>
          <h4>{ I18n.t( "about_community_taxa" ) }</h4>
          <div
            dangerouslySetInnerHTML={ { __html:
              I18n.t( "views.observations.show.community_taxon_desc_html", {
                site_name: SITE.name } ) } }
          />
          { algorithmSummary }
        </Modal.Body>
        <Modal.Footer>
         <div className="buttons">
            <Button bsStyle="primary" onClick={ this.close }>
              { I18n.t( "ok" ) }
            </Button>
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

CommunityIDModal.propTypes = {
  observation: PropTypes.object,
  setCommunityIDModalState: PropTypes.func,
  show: PropTypes.bool,
  config: PropTypes.object
};

CommunityIDModal.defaultProps = {
  config: {}
};

export default CommunityIDModal;
