import React, { PropTypes } from "react";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import _ from "lodash";
import inatjs from "inaturalistjs";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";

class TaxonChooserPopover extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      taxa: [],
      current: -1
    };
  }

  componentDidMount( ) {
    this.setTaxaFromProps( this.props );
  }

  componentWillReceiveProps( newProps ) {
    this.setTaxaFromProps( newProps );
  }

  setTaxaFromProps( props ) {
    if ( props.taxon ) {
      if ( props.taxon.ancestors && props.taxon.ancestors.length > 0 ) {
        this.setState( { taxa: _.sortBy( props.taxon.ancestors, t => ( t.rank_level || 999 ) ) } );
      } else if ( props.taxon.ancestor_ids ) {
        inatjs.taxa.fetch( props.taxon.ancestor_ids ).then( response => {
          let newTaxa = _.sortBy( response.results, t => ( t.rank_level || 999 ) );
          if (
            this.props.defaultTaxon &&
            this.props.taxon &&
            this.props.taxon.id !== this.props.defaultTaxon.id
          ) {
            newTaxa = _.filter( newTaxa, p => p.id !== this.props.defaultTaxon.id );
            newTaxa.splice( 0, 0, this.props.defaultTaxon );
          }
          this.setState( { taxa: newTaxa } );
        } );
      }
    }
  }


  chooseCurrent( ) {
    const currentTaxon = this.state.taxa[this.state.current];
    // Dumb, but I don't see a better way to explicity close the popover
    $( "body" ).click( );
    if ( currentTaxon ) {
      this.props.setTaxon( currentTaxon );
    } else {
      this.props.clearTaxon( );
    }
  }

  render( ) {
    const {
      container,
      taxon,
      className,
      setTaxon,
      clearTaxon,
      preIconClass,
      postIconClass,
      label
    } = this.props;
    return (
      <OverlayTrigger
        trigger="click"
        placement="bottom"
        rootClose
        container={container}
        overlay={
          <Popover className="TaxonChooserPopover RecordChooserPopover">
            <TaxonAutocomplete
              initialSelection={taxon}
              bootstrapClear
              searchExternal={false}
              resetOnChange={false}
              afterSelect={ result => {
                setTaxon( result.item );
                $( "body" ).click( );
              } }
              afterUnselect={ ( ) => {
                clearTaxon( );
                $( "body" ).click( );
              } }
            />
            <ul className="list-unstyled">
              <li
                className={this.state.current === -1 ? "current" : ""}
                onMouseOver={( ) => {
                  this.setState( { current: -1 } );
                }}
                onClick={( ) => this.chooseCurrent( )}
                className="pinned"
                style={{ display: this.props.taxon ? "block" : "none" }}
              >
                <i className="fa fa-times"></i>
                { _.capitalize( I18n.t( "clear" ) ) }
              </li>
              { _.map( this.state.taxa, ( t, i ) => (
                <li
                  key={`taxon-chooser-taxon-${t.id}`}
                  className={
                    `media ${this.state.current === i ? "current" : ""}
                    ${this.props.defaultTaxon && t.id === this.props.defaultTaxon.id ? "pinned" : ""}`
                  }
                  onClick={( ) => this.chooseCurrent( )}
                  onMouseOver={( ) => {
                    this.setState( { current: i } );
                  }}
                >
                  <div className="media-left">
                    <i className={`media-object icon-iconic-${( t.iconic_taxon_name || "unknown" ).toLowerCase( )}`}></i>
                  </div>
                  <div className="media-body">
                    <SplitTaxon taxon={t} forceRank />
                  </div>
                </li>
              ) ) }
            </ul>
          </Popover>
        }
      >
        <div
          className={`TaxonChooserPopoverTrigger RecordChooserPopoverTrigger ${taxon ? "chosen" : ""} ${className}`}
        >
          { preIconClass ? <i className={`${preIconClass} pre-icon`}></i> : null }
          { label ? ( <label>{ label }</label> ) : null }
          {
            taxon ?
              <SplitTaxon taxon={taxon} />
              :
              _.startCase( I18n.t( "filter_by_taxon" ) ) }
          { postIconClass ? <i className={`${postIconClass} post-icon`}></i> : null }
        </div>
      </OverlayTrigger>
    );
  }
}

TaxonChooserPopover.propTypes = {
  container: PropTypes.object,
  taxon: PropTypes.object,
  defaultTaxon: PropTypes.object,
  className: PropTypes.string,
  setTaxon: PropTypes.func,
  clearTaxon: PropTypes.func,
  preIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  postIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  label: PropTypes.string
};

TaxonChooserPopover.defaultProps = {
  preIconClass: "fa fa-search"
};

export default TaxonChooserPopover;
