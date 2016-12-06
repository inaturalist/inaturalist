import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import moment from "moment";
import { urlForTaxon, commasAnd } from "../../shared/util";

const TaxonChangeAlert = ( { taxon, taxonChange } ) => {
  if ( !taxonChange || ( taxon.is_active && taxonChange.input_taxa[0].id !== taxon.id ) ) {
    return ( <div></div> );
  }
  const committedOn = taxonChange.committed_on ? moment( taxonChange.committed_on ) : null;
  const linkToTaxon = ( t ) =>
    `<a href=${urlForTaxon( t )} class="sciname ${t.rank.toLowerCase( )}">${t.name}</a>`;
  const renderTaxonSwap = ( ) => {
    if ( committedOn ) {
      return I18n.t( "change_types.input_taxon_was_replaced_by_output_taxon", {
        input_taxon: linkToTaxon( taxonChange.input_taxa[0] ),
        output_taxon: linkToTaxon( taxonChange.output_taxa[0] )
      } );
    }
    return I18n.t( "change_types.input_taxon_will_be_replaced_by_output_taxon", {
      input_taxon: linkToTaxon( taxonChange.input_taxa[0] ),
      output_taxon: linkToTaxon( taxonChange.output_taxa[0] )
    } );
  };
  const renderTaxonSplit = ( ) => {
    if ( committedOn ) {
      return I18n.t( "change_types.input_taxon_was_split_into_output_taxa_html", {
        input_taxon: linkToTaxon( taxonChange.input_taxa[0] ),
        output_taxa: commasAnd( taxonChange.output_taxa.map( ot => linkToTaxon( ot ) ) )
      } );
    }
    return I18n.t( "change_types.input_taxon_will_be_split_into_output_taxa_html", {
      input_taxon: linkToTaxon( taxonChange.input_taxa[0] ),
      output_taxa: commasAnd( taxonChange.output_taxa.map( ot => linkToTaxon( ot ) ) )
    } );
  };
  const renderTaxonMerge = ( ) => {
    if ( committedOn ) {
      return I18n.t( "change_types.input_taxa_were_merged_into_output_taxon_html", {
        input_taxa: commasAnd( taxonChange.input_taxa.map( ot => linkToTaxon( ot ) ) ),
        output_taxon: linkToTaxon( taxonChange.output_taxa[0] )
      } );
    }
    return I18n.t( "change_types.input_taxa_will_be_merged_into_output_taxon_html", {
      input_taxa: commasAnd( taxonChange.input_taxa.map( ot => linkToTaxon( ot ) ) ),
      output_taxon: linkToTaxon( taxonChange.output_taxa[0] )
    } );
  };
  const renderTaxonDrop = ( ) => {
    if ( committedOn ) {
      return I18n.t( "change_types.input_taxon_was_dropped_html", {
        input_taxon: linkToTaxon( taxonChange.input_taxa[0] )
      } );
    }
    return I18n.t( "change_types.input_taxon_will_be_dropped_html", {
      input_taxon: linkToTaxon( taxonChange.input_taxa[0] )
    } );
  };
  let content;
  switch ( taxonChange.type ) {
    case "TaxonSwap":
      content = renderTaxonSwap( );
      break;
    case "TaxonSplit":
      content = renderTaxonSplit( );
      break;
    case "TaxonMerge":
      content = renderTaxonMerge( );
      break;
    case "TaxonDrop":
      content = renderTaxonDrop( );
      break;
    default:
      content = null;
  }
  return (
    <Row>
      <Col xs={12}>
        <div className="alert alert-warning">
          <strong>{
            I18n.t( "heads_up" )
          }:</strong> {
            taxon.is_active ? null : `${I18n.t( "this_taxon_concept_is_inactive" )}.`
          } {
            content ? (
              <span><span dangerouslySetInnerHTML={ { __html: content } } /><span>.</span></span>
            ) : null
          } <a className="readmore" href={`/taxon_changes/${taxonChange.id}`}>
            { I18n.t( "view_taxon_change" ) }
          </a>
        </div>
      </Col>
    </Row>
  );
};

TaxonChangeAlert.propTypes = {
  taxon: PropTypes.object,
  taxonChange: PropTypes.object
};

export default TaxonChangeAlert;
