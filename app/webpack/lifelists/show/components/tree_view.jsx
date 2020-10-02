import React from "react";
import PropTypes from "prop-types";
import TaxaTreeContainer from "../containers/taxa_tree_container";
import TaxaListContainer from "../containers/taxa_list_container";

class TreeView extends React.Component {
  rankOptions( ) {
    const {
      lifelist, setTreeMode
    } = this.props;
    let label = lifelist.treeMode === "simplified"
      ? I18n.t( "views.lifelists.dropdowns.simplified_tree" )
      : I18n.t( "views.lifelists.dropdowns.full_taxonomy" );
    label = `${I18n.t( "view" )}: ${label}`;
    return (
      <div className="dropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="rankDropdown"
        >
          { label }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="rankDropdown">
          <li
            onClick={( ) => setTreeMode( lifelist.treeMode === "simplified" ? "tree" : "simplified" )}
          >
            { lifelist.treeMode === "simplified"
              ? I18n.t( "views.lifelists.dropdowns.full_taxonomy" )
              : I18n.t( "views.lifelists.dropdowns.simplified_tree" )
            }
          </li>
        </ul>
      </div>
    );
  }

  sortOptions( ) {
    const { lifelist, setTreeSort } = this.props;
    let sortLabel = I18n.t( "views.lifelists.dropdowns.most_observed" );
    if ( lifelist.treeSort === "name" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.name" );
    } else if ( lifelist.treeSort === "taxonomic" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.taxonomic" );
    }
    sortLabel = `${I18n.t( "views.lifelists.dropdowns.sort" )}: ${sortLabel}`;
    return (
      <div className="dropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="sortDropdown"
        >
          { sortLabel }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="sortDropdown">
          <li
            className={lifelist.treeSort === "obsDesc" ? "selected" : null}
            onClick={( ) => setTreeSort( "obsDesc" )}
          >
            { I18n.t( "views.lifelists.dropdowns.most_observed" ) }
          </li>
          <li
            className={lifelist.treeSort === "name" ? "selected" : null}
            onClick={( ) => setTreeSort( "name" )}
          >
            { I18n.t( "views.lifelists.dropdowns.name" ) }
          </li>
          <li
            className={lifelist.treeSort === "taxonomic" ? "selected" : null}
            onClick={( ) => setTreeSort( "taxonomic" )}
          >
            { I18n.t( "views.lifelists.dropdowns.taxonomic" ) }
          </li>
        </ul>
      </div>
    );
  }

  ancestryOptions( ) {
    this.ssh = "ssh";
    const { lifelist, setListShowAncestry } = this.props;
    let label = I18n.t( "hide" );
    if ( lifelist.listShowAncestry ) {
      label = I18n.t( "show" );
    }
    label = `${I18n.t( "views.lifelists.dropdowns.ancestry" )}: ${label}`;

    return (
      <div className="dropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="ancestryDropdown"
        >
          { label }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="ancestryDropdown">
          <li
            className={lifelist.listShowAncestry ? "selected" : null}
            onClick={( ) => setListShowAncestry( !lifelist.listShowAncestry )}
          >
            { lifelist.listShowAncestry ? I18n.t( "hide" ) : I18n.t( "show" ) }
          </li>
        </ul>
      </div>
    );
  }

  render( ) {
    const { lifelist } = this.props;
    let treeComponent;
    if ( lifelist.navView === "tree" ) {
      treeComponent = ( <TaxaTreeContainer /> );
    } else if ( lifelist.navView === "list" ) {
      treeComponent = ( <TaxaListContainer /> );
    }
    return (
      <div className="Details">
        <div className="search-options">
          { this.sortOptions( ) }
          { lifelist.navView === "tree" && this.rankOptions( ) }
          { lifelist.navView === "list" && this.ancestryOptions( ) }
        </div>
        { treeComponent }
      </div>
    );
  }
}

TreeView.propTypes = {
  lifelist: PropTypes.object,
  setTreeSort: PropTypes.func,
  setTreeMode: PropTypes.func,
  setListShowAncestry: PropTypes.func
};

export default TreeView;
