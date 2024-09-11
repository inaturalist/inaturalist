import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";
import { CSVLink } from "react-csv";
import moment from "moment-timezone";
import ReactDOMServer from "react-dom/server";
import SplitTaxon from "../../../shared/components/split_taxon";

moment.locale( I18n.locale );

class ExportModal extends Component {
  constructor( ) {
    super( );
    this.cancel = this.cancel.bind( this );
    this.close = this.close.bind( this );
    this.confirm = this.confirm.bind( this );
    this.taxaToExport = this.taxaToExport.bind( this );
    this.startExport = this.startExport.bind( this );
    this.state = {
      dataToDownload: [],
      generating: false,
      filterTaxon: false,
      filterPlace: false,
      filterLeaves: false
    };
  }

  close( ) {
    this.props.setExportModalState( { show: false } );
    this.state = {
      dataToDownload: [],
      generating: false
    };
  }

  confirm( ) {
    this.close( );
  }

  cancel( ) {
    this.close( );
  }

  taxaToExport( ) {
    if ( !this.props.show ) {
      return [];
    }
    let taxonFilter;
    let placeFilter;
    let leafFilter;
    const { lifelist, inatAPI } = this.props;
    if ( this.state.filterLeaves ) {
      leafFilter = t => t.right === t.left + 1;
    }
    if ( this.state.filterTaxon && lifelist.detailsTaxon && lifelist.detailsTaxon !== "root" ) {
      taxonFilter = node => {
        if ( node.left >= lifelist.detailsTaxon.left
          && node.right <= lifelist.detailsTaxon.right ) {
          return true;
        }
        if ( lifelist.detailsTaxon.left >= node.left
          && lifelist.detailsTaxon.right <= node.right ) {
          return true;
        }
        return false;
      };
    }
    if ( this.state.filterPlace && lifelist.speciesPlaceFilter ) {
      const inatAPIsearch = inatAPI.speciesPlace;
      const searchLoaded = inatAPIsearch
        && inatAPIsearch.searchResponse && inatAPIsearch.loaded;
      if ( searchLoaded ) {
        placeFilter = t => inatAPIsearch.searchResponse.results[t.id];
      }
    }
    if ( taxonFilter || placeFilter || leafFilter ) {
      return _.filter( lifelist.taxa, t => {
        if ( leafFilter && !leafFilter( t ) ) { return false; }
        if ( taxonFilter && !taxonFilter( t ) ) { return false; }
        if ( placeFilter && !placeFilter( t ) ) { return false; }
        return true;
      } );
    }
    return _.values( lifelist.taxa );
  }

  startExport( ) {
    this.setState( { generating: true } );
    const dataToDownload = [[
      "id", "parent_id", "name", "common_name", "rank", "is_leaf",
      "direct_observation_count", "total_observation_count"
    ]];
    const taxa = _.sortBy( this.taxaToExport( ), "left" );
    _.each( taxa, t => {
      dataToDownload.push( [
        t.id, t.parent_id, t.name, t.preferred_common_name, t.rank, t.right === t.left + 1,
        t.direct_obs_count, t.descendant_obs_count
      ] );
    } );
    this.setState( { dataToDownload }, ( ) => {
      setTimeout( ( ) => {
        // trigger the download
        this.csvLink.link.click( );
        this.setState( { dataToDownload: [] } );
        setTimeout( ( ) => {
          this.setState( { generating: false } );
        }, 1000 );
      }, 100 );
    } );
  }

  render( ) {
    const { lifelist, config } = this.props;
    const filterOptions = [(
      <li key="export-filter-leaves">
        <input
          type="checkbox"
          id="export-leaves-filter"
          defaultChecked={this.state.filterLeaves}
          onChange={e => {
            this.setState( { filterLeaves: e.target.checked } );
          }}
        />
        <label className="sectionlabel" htmlFor="export-leaves-filter">
          { I18n.t( "views.lifelists.restrict_to_leaf_taxa" ) }
        </label>
      </li>
    )];
    if ( lifelist.detailsTaxon && lifelist.detailsTaxon !== "root" ) {
      filterOptions.push(
        <li key="export-filter-taxon">
          <input
            type="checkbox"
            id="export-taxon-filter"
            defaultChecked={this.state.filterTaxon}
            onChange={e => {
              this.setState( { filterTaxon: e.target.checked } );
            }}
          />
          <label
            className="sectionlabel"
            htmlFor="export-taxon-filter"
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.lifelists.restrict_to_taxon", {
                taxon: ReactDOMServer.renderToString(
                  <span className="filter-label">
                    <SplitTaxon
                      taxon={lifelist.detailsTaxon}
                      user={config.currentUser}
                    />
                  </span>
                )
              } )
            }}
          />
        </li>
      );
    }
    if ( lifelist.speciesPlaceFilter ) {
      filterOptions.push(
        <li key="export-filter-place">
          <input
            type="checkbox"
            id="export-place-filter"
            defaultChecked={this.state.filterPlace}
            onChange={e => {
              this.setState( { filterPlace: e.target.checked } );
            }}
          />
          <label
            className="sectionlabel"
            htmlFor="export-place-filter"
            dangerouslySetInnerHTML={{
              __html: I18n.t( "views.lifelists.restrict_to_taxa_observed_in_place", {
                place: ReactDOMServer.renderToString(
                  <span className="filter-label">
                    {lifelist.speciesPlaceFilter.display_name}
                  </span>
                )
              } )
            }}
          />
        </li>
      );
    }
    let filename = `life-list-${lifelist.user.login}-`;
    if ( this.state.filterLeaves ) {
      filename += "leaves-";
    }
    if ( this.state.filterTaxon && lifelist.detailsTaxon ) {
      filename += `taxon-${lifelist.detailsTaxon.id}-`;
    }
    if ( this.state.filterPlace && lifelist.speciesPlaceFilter ) {
      filename += `place-${lifelist.speciesPlaceFilter.id}-`;
    }
    filename += `${moment( ).format( "YYYYMMDDHHMMSS" )}.csv`;
    const exportingTaxonCount = this.props.show
      ? _.size( this.taxaToExport( ) ) : 0;
    let taxonCountText;
    if ( this.props.show ) {
      if ( exportingTaxonCount === 0 ) {
        taxonCountText = I18n.t( "no_matching_taxa" );
      } else {
        taxonCountText = exportingTaxonCount === _.size( lifelist.taxa )
          ? I18n.t( "views.lifelists.exporting_all_x_taxa", { count: exportingTaxonCount } )
          : I18n.t( "views.lifelists.exporting_x_taxa", { count: exportingTaxonCount } );
      }
    }
    return (
      <Modal
        show={this.props.show}
        className="ExportModal"
        onHide={this.close}
      >
        <Modal.Header>
          { I18n.t( "export" ) }
        </Modal.Header>
        <Modal.Body>
          { _.isEmpty( filterOptions ) ? null : (
            <div className="export-filters">
              <span className="intro">
                { I18n.t( "views.lifelists.apply_filters_to_export" ) }
              </span>
              <ul>{ filterOptions }</ul>
            </div>
          ) }
        </Modal.Body>
        <Modal.Footer>
          { taxonCountText && (
            <div className="taxa-count">
              { taxonCountText }
            </div>
          ) }
          <Button
            bsStyle="primary"
            onClick={this.startExport}
            disabled={exportingTaxonCount === 0}
          >
            {this.state.generating ? ( <div className="loading_spinner" /> ) : I18n.t( "export" ) }
          </Button>
          <Button onClick={this.confirm}>
            { I18n.t( "close" ) }
          </Button>
        </Modal.Footer>
        <CSVLink
          data={this.state.dataToDownload}
          filename={filename}
          className="hidden"
          ref={r => { this.csvLink = r; }}
          target="_blank"
          rel="noopener noreferrer"
        />
      </Modal>
    );
  }
}

ExportModal.propTypes = {
  config: PropTypes.object,
  show: PropTypes.bool,
  lifelist: PropTypes.object,
  inatAPI: PropTypes.object,
  setExportModalState: PropTypes.func
};

export default ExportModal;
