import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";
import TreeViewContainer from "../containers/tree_view_container";
import DetailsViewContainer from "../containers/details_view_container";
import ExportModalContainer from "../containers/export_modal_container";
import FlashMessagesContainer from "../../../shared/containers/flash_messages_container";


/* global inaturalist */
/* global LIFE_TAXON */

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
        <FlashMessagesContainer />
        <div className="lifelist-title">
          <h1>
            { I18n.t( "life_list", { user: lifelist.user.login } ) }
            <button
              type="button"
              className="btn btn-primary export"
              onClick={( ) => setExportModalState( { show: true } )}
            >
              { I18n.t( "export" ) }
            </button>
          </h1>
        </div>
        <div className="FlexGrid">
          <div className="FlexCol tree-col">
            <div className="view-selectors">
              <button
                type="button"
                className={`btn pill-button ${lifelist.navView === "list" ? "selected" : ""}`}
                onClick={( ) => setNavView( "list" )}
              >
                <span className="fa fa-bars" />
                { I18n.t( "views.lifelists.list_view" ) }
              </button>
              <button
                type="button"
                className={`btn pill-button ${lifelist.navView === "tree" ? "selected" : ""}`}
                onClick={( ) => setNavView( "tree" )}
              >
                <span className="icon-treeview" />
                { I18n.t( "views.lifelists.tree_view" ) }
              </button>
            </div>
            <div className="iconic-taxa-selectors">
              { _.map( _.sortBy( inaturalist.ICONIC_TAXA, "name" ), t => {
                const selected = lifelist.detailsTaxon && lifelist.detailsTaxon.id === t.id;
                return (
                  <button
                    type="button"
                    title={I18n.t( `all_taxa.${t.label}` )}
                    className={`iconic-taxon-icon ${selected ? "selected" : ""}`}
                    key={`iconic-taxon-${_.toLower( t.name )}`}
                    disabled={!lifelist.taxa[t.id]}
                    onClick={( ) => {
                      if ( selected ) {
                        setDetailsTaxon( null, { updateSearch: true } );
                      } else {
                        zoomToTaxon( t.id );
                      }
                    }}
                  >
                    <i
                      className={`icon-iconic-${_.toLower( t.name )}`}
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
              notIDs={[LIFE_TAXON.id]}
              initialSelection={lifelist.searchTaxon}
              afterSelect={e => {
                zoomToTaxon( e.item.id );
              }}
              afterUnselect={( ) => {
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
                className={`btn pill-button ${lifelist.detailsView === "species" ? "selected" : ""}`}
                onClick={( ) => setDetailsView( "species" )}
              >
                <span className="fa fa-leaf" />
                { I18n.t( "species" ) }
              </button>
              <button
                type="button"
                className={`btn pill-button ${lifelist.detailsView === "observations" ? "selected" : ""}`}
                onClick={( ) => setDetailsView( "observations" )}
              >
                <span className="fa fa-binoculars" />
                { I18n.t( "observations" ) }
              </button>
              <button
                type="button"
                className={`btn pill-button ${lifelist.detailsView === "unobservedSpecies" ? "selected" : ""}`}
                onClick={( ) => setDetailsView( "unobservedSpecies" )}
              >
                <span className="fa fa-eye-slash" />
                { I18n.t( "views.lifelists.unobserved_species" ) }
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
