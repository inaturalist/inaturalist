import React from "react";
import PropTypes from "prop-types";
import TaxaTreeContainer from "../containers/taxa_tree_container";
import TaxaListContainer from "../containers/taxa_list_container";

class TreeView extends React.Component {
  rankOptions( ) {
    const {
      lifelist, setTreeMode
    } = this.props;
    const rankLabel = `SimpleTree: ${lifelist.treeMode === "simplified" ? "on" : "off"}`;
    return (
      <div className="dropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="rankDropdown"
        >
          { rankLabel }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="rankDropdown">
          <li
            onClick={( ) => setTreeMode( lifelist.treeMode === "simplified" ? "tree" : "simplified" )}
          >
            SimpleTree: { lifelist.treeMode === "simplified" ? "off" : "on" }
          </li>
        </ul>
      </div>
    );
  }

  sortOptions( ) {
    this.ssh = "ssh";
    const { lifelist, setTreeSort } = this.props;
    let sortLabel = "Sort: Total Observations";
    if ( lifelist.treeSort === "name" ) {
      sortLabel = "Sort: Name";
    } else if ( lifelist.treeSort === "taxonomic" ) {
      sortLabel = "Sort: Taxonomic";
    }
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
            Total Observations
          </li>
          <li
            className={lifelist.treeSort === "name" ? "selected" : null}
            onClick={( ) => setTreeSort( "name" )}
          >
            Name
          </li>
          <li
            className={lifelist.treeSort === "taxonomic" ? "selected" : null}
            onClick={( ) => setTreeSort( "taxonomic" )}
          >
            Taxonomic
          </li>
        </ul>
      </div>
    );
  }

  ancestryOptions( ) {
    this.ssh = "ssh";
    const { lifelist, setListShowAncestry } = this.props;
    let sortLabel = "Ancestry: Hide";
    if ( lifelist.listShowAncestry ) {
      sortLabel = "Ancestry: Show";
    }
    return (
      <div className="dropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="ancestryDropdown"
        >
          { sortLabel }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="ancestryDropdown">
          <li
            className={lifelist.listShowAncestry ? "selected" : null}
            onClick={( ) => setListShowAncestry( !lifelist.listShowAncestry )}
          >
            Ancestry: { lifelist.listShowAncestry ? "Hide" : "Show" }
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
  config: PropTypes.object,
  lifelist: PropTypes.object,
  setNavView: PropTypes.func,
  setTreeSort: PropTypes.func,
  setListViewRankFilter: PropTypes.func,
  setTreeMode: PropTypes.func,
  setListShowAncestry: PropTypes.func
};

export default TreeView;
