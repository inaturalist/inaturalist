import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";
import TreeViewContainer from "../containers/tree_view_container";
import DetailsViewContainer from "../containers/details_view_container";
import ExportModalContainer from "../containers/export_modal_container";


/* global inaturalist */

class App extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.taxonAutocomplete = React.createRef( );
  }

  render( ) {
    const {
      lifelist, config, zoomToTaxon, setNavView, setSearchTaxon,
      setDetailsView, setDetailsTaxon, setExportModalState
    } = this.props;
    return (
      <div id="Lifelist" className="container">
        <div className="lifelist-title">
          <h1>
            { I18n.t( "life_list", { user: lifelist.user.login } ) }
              <button
                type="button"
                className="btn btn-primary export"
                onClick={( ) => setExportModalState( { show: true } )}
              >
                Export
              </button>
          </h1>
        </div>
        <div className="FlexGrid">
          <div className="FlexCol tree-col">
            <div className="view-selectors">
              <button
                type="button"
                className={`btn pill-button ${lifelist.navView === "tree" ? "selected" : ""}`}
                onClick={( ) => setNavView( "tree" )}
              >
                <span className="icon-treeview" />
                Tree View
              </button>
              <button
                type="button"
                className={`btn pill-button ${lifelist.navView === "list" ? "selected" : ""}`}
                onClick={( ) => setNavView( "list" )}
              >
                <span className="fa fa-bars" />
                List View
              </button>
            </div>
            <div className="iconic-taxa-selectors">
              { _.map( _.sortBy( inaturalist.ICONIC_TAXA, "name" ), t => {
                const selected = lifelist.detailsTaxon && lifelist.detailsTaxon.id === t.id;
                return (
                  <button
                    type="button"
                    className={`iconic-taxon-icon ${selected ? "selected" : ""}`}
                    key={`iconic-taxon-${_.toLower( t.name )}`}
                    disabled={!lifelist.taxa[t.id]}
                    onClick={( ) => selected
                      ? setDetailsTaxon( null, { updateSearch: true } )
                      : zoomToTaxon( t.id )
                    }
                  >
                    <i
                      className={`icon-iconic-${_.toLower( t.name )}`}
                      title={t.name}
                    />
                  </button>
                );
              } ) }
            </div>
            <TaxonAutocomplete
              key={`autocomplete-details-${lifelist.searchTaxon ? lifelist.searchTaxon.id : null}`}
              ref={this.taxonAutocomplete}
              bootstrap
              noThumbnail
              perPage={6}
              searchExternal={false}
              resetOnChange={false}
              initialSelection={lifelist.searchTaxon}
              afterSelect={e => {
                zoomToTaxon( e.item.id );
              }}
              afterUnselect={e => {
                setSearchTaxon( null );
              }}
              observedByUserID={lifelist.user.id}
              config={config}
              placeholder={I18n.t( "taxon_autocomplete_placeholder" )}
            />
            <TreeViewContainer />
          </div>
          <div className="FlexCol details-col">
            <div className="view-selectors">
              <button
                type="button"
                className={`btn pill-button ${lifelist.detailsView === "observations" ? "selected" : ""}`}
                onClick={( ) => setDetailsView( "observations" )}
              >
                <span className="fa fa-binoculars" />
                Observations
              </button>
              <button
                type="button"
                className={`btn pill-button ${lifelist.detailsView === "species" ? "selected" : ""}`}
                onClick={( ) => setDetailsView( "species" )}
              >
                <span className="fa fa-leaf" />
                Species
              </button>
              <button
                type="button"
                className={`btn pill-button ${lifelist.detailsView === "unobservedSpecies" ? "selected" : ""}`}
                onClick={( ) => setDetailsView( "unobservedSpecies" )}
              >
                <span className="fa fa-eye-slash" />
                Unobserved Species
              </button>
            </div>
            <DetailsViewContainer />
          </div>
        </div>
        <ExportModalContainer />
      </div>
    );
  }
}

App.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  setNavView: PropTypes.func,
  setDetailsTaxon: PropTypes.func,
  setSearchTaxon: PropTypes.func,
  setDetailsView: PropTypes.func,
  zoomToTaxon: PropTypes.func,
  setExportModalState: PropTypes.func
};

export default App;
