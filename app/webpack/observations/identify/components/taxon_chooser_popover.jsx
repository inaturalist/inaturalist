import React from "react";
import PropTypes from "prop-types";
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
    const propsEqual = _.isEqual(
      _.filter( this.props, v => !_.isFunction( v ) ),
      _.filter( newProps, v => !_.isFunction( v ) )
    );
    if ( !propsEqual ) {
      this.setTaxaFromProps( newProps );
    }
  }

  setTaxaFromProps( props ) {
    const { taxon, defaultTaxon, config } = this.props;
    if ( props.taxon ) {
      if ( props.taxon.ancestors && props.taxon.ancestors.length > 0 ) {
        this.setState( { taxa: _.sortBy( props.taxon.ancestors, t => ( t.rank_level || 999 ) ) } );
      } else if ( props.taxon.ancestor_ids ) {
        const params = { };
        if ( config.testingApiV2 ) {
          params.fields = {
            ancestor_ids: true,
            id: true,
            name: true,
            rank: true,
            rank_level: true,
            iconic_taxon_name: true,
            is_active: true,
            preferred_common_name: true
          };
        }
        inatjs.taxa.fetch( props.taxon.ancestor_ids, params ).then( response => {
          let newTaxa = _.sortBy( response.results, t => ( t.rank_level || 999 ) );
          if (
            defaultTaxon
            && taxon
            && taxon.id !== defaultTaxon.id
          ) {
            newTaxa = _.filter( newTaxa, p => p.id !== defaultTaxon.id );
            newTaxa.splice( 0, 0, defaultTaxon );
          }
          this.setState( { taxa: newTaxa } );
        } );
      }
    }
  }

  chooseCurrent( ) {
    const { taxa, current } = this.state;
    const { setTaxon, clearTaxon } = this.props;
    const currentTaxon = taxa[current];
    // Dumb, but I don't see a better way to explicity close the popover
    $( "body" ).click( );
    if ( currentTaxon ) {
      setTaxon( currentTaxon );
    } else {
      clearTaxon( );
    }
  }

  render( ) {
    const {
      id,
      container,
      taxon,
      defaultTaxon,
      className,
      setTaxon,
      clearTaxon,
      preIconClass,
      postIconClass,
      label,
      config
    } = this.props;
    const { current, taxa } = this.state;
    return (
      <OverlayTrigger
        trigger="click"
        placement="bottom"
        rootClose
        container={container}
        overlay={(
          <Popover id={id} className="TaxonChooserPopover RecordChooserPopover">
            <TaxonAutocomplete
              initialSelection={taxon}
              bootstrapClear
              searchExternal={false}
              resetOnChange={false}
              afterSelect={result => {
                setTaxon( result.item );
                $( "body" ).click( );
              }}
              afterUnselect={( ) => {
                if ( typeof ( clearTaxon ) === "function" ) {
                  clearTaxon( );
                }
              }}
            />
            <ul className="list-unstyled">
              <li
                className={current === -1 ? "pinned current" : "pinned"}
                onMouseOver={( ) => this.setState( { current: -1 } )}
                onFocus={( ) => this.setState( { current: -1 } )}
                style={{ display: taxon ? "block" : "none" }}
              >
                <button
                  type="button"
                  onClick={( ) => this.chooseCurrent( )}
                  className="btn btn-nostyle"
                >
                  <i className="fa fa-times" />
                  { I18n.t( "clear" ) }
                </button>
              </li>
              { _.map( taxa, ( t, i ) => (
                <li
                  key={`taxon-chooser-taxon-${t.id}`}
                  className={
                    `media ${current === i ? "current" : ""}
                    ${defaultTaxon && t.id === defaultTaxon.id ? "pinned" : ""}`
                  }
                  onMouseOver={( ) => this.setState( { current: i } )}
                  onFocus={( ) => this.setState( { current: i } )}
                >
                  <button
                    type="button"
                    className="btn btn-nostyle"
                    onClick={( ) => this.chooseCurrent( )}
                  >
                    <div className="media-left">
                      <i className={`media-object icon-iconic-${( t.iconic_taxon_name || "unknown" ).toLowerCase( )}`} />
                    </div>
                    <div className="media-body">
                      <SplitTaxon taxon={t} user={config.currentUser} />
                    </div>
                  </button>
                </li>
              ) ) }
            </ul>
          </Popover>
        )}
      >
        <div
          className={`TaxonChooserPopoverTrigger RecordChooserPopoverTrigger ${taxon ? "chosen" : ""} ${className}`}
        >
          { preIconClass ? <i className={`${preIconClass} pre-icon`} /> : null }
          { label ? ( <label>{ label }</label> ) : null }
          {
            taxon
              ? <SplitTaxon taxon={taxon} user={config.currentUser} />
              : I18n.t( "filter_by_taxon" )
          }
          { postIconClass ? <i className={`${postIconClass} post-icon`} /> : null }
        </div>
      </OverlayTrigger>
    );
  }
}

TaxonChooserPopover.propTypes = {
  id: PropTypes.string.isRequired,
  container: PropTypes.object,
  taxon: PropTypes.object,
  defaultTaxon: PropTypes.object,
  className: PropTypes.string,
  setTaxon: PropTypes.func,
  clearTaxon: PropTypes.func,
  preIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  postIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  label: PropTypes.string,
  config: PropTypes.object
};

TaxonChooserPopover.defaultProps = {
  preIconClass: "fa fa-search",
  config: {}
};

export default TaxonChooserPopover;
