import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import TaxaTreeContainer from "../containers/taxa_tree_container";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";
import DetailsViewContainer from "../containers/details_view_container";

/* global inaturalist */

class App extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.taxonAutocomplete = React.createRef( );
  }

  render( ) {
    const {
      lifelist, config, zoomToTaxon, setNavView, setDetailsView
    } = this.props;
    return (
      <div id="Lifelist" className="container">
        <div className="lifelist-title">
          <h1>
            { I18n.t( "life_list", { user: lifelist.user.login } ) }
            <a href={`/lifelists/${lifelist.user.login}.csv`}>
              <button
                type="button"
                className="btn btn-primary export"
              >
                Export
              </button>
            </a>
          </h1>
        </div>
        <div className="FlexGrid">
          <div className="FlexCol tree-col">
            <h2>Explore</h2>
            <div className="view-selectors">
              <button
                type="button"
                className={`btn pill-button ${lifelist.navView === "tree" ? "selected" : ""}`}
                onClick={( ) => setNavView( "tree" )}
              >
                <span className="fa fa-align-left" />
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
              <span className="jump-to">Jump to:</span>
              { _.map( _.sortBy( inaturalist.ICONIC_TAXA, "name" ), t => (
                <button
                  type="button"
                  className={`iconic-taxon-icon ${lifelist.detailsTaxon && lifelist.detailsTaxon.id === t.id ? "selected" : ""}`}
                  key={`iconic-taxon-${_.toLower( t.name )}`}
                  disabled={!lifelist.taxa[t.id]}
                  onClick={( ) => zoomToTaxon( t.id )}
                >
                  <i
                    className={`icon-iconic-${_.toLower( t.name )}`}
                    title={t.name}
                  />
                </button>
              ) ) }
            </div>
            <TaxonAutocomplete
              key={`autocomplete-details-${lifelist.detailsTaxon ? lifelist.detailsTaxon.id : null}`}
              ref={this.taxonAutocomplete}
              bootstrap
              noThumbnail
              perPage={6}
              searchExternal={false}
              initialSelection={lifelist.detailsTaxon}
              afterSelect={e => {
                zoomToTaxon( e.item.id );
              }}
              observedByUserID={lifelist.user.id}
              config={config}
              placeholder={I18n.t( "taxon_autocomplete_placeholder" )}
            />
            { lifelist.navView === "tree"
              ? ( <TaxaTreeContainer /> )
              : "todo"
            }
          </div>
          <div className="FlexCol details-col">
            <h2>View</h2>
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
      </div>
    );
  }
}

App.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  setNavView: PropTypes.func,
  setDetailsView: PropTypes.func,
  zoomToTaxon: PropTypes.func
};

export default App;
