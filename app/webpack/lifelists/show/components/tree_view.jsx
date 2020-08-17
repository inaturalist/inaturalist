import React from "react";
import PropTypes from "prop-types";
import TaxaTreeContainer from "../containers/taxa_tree_container";
import TaxaListContainer from "../containers/taxa_list_container";

class TreeView extends React.Component {
  rankOptions( ) {
    const {
      lifelist, setListViewRankFilter, setTreeMode, setTreeIndent, setNavView
    } = this.props;
    let rankLabel = "Show: Default";
    if ( lifelist.listViewRankFilter === "kingdoms" ) {
      rankLabel = "Show: Kingdoms";
    } else if ( lifelist.listViewRankFilter === "phylums" ) {
      rankLabel = "Show: Phylums";
    } else if ( lifelist.listViewRankFilter === "classes" ) {
      rankLabel = "Show: Classes";
    } else if ( lifelist.listViewRankFilter === "orders" ) {
      rankLabel = "Show: Orders";
    } else if ( lifelist.listViewRankFilter === "families" ) {
      rankLabel = "Show: Families";
    } else if ( lifelist.listViewRankFilter === "genera" ) {
      rankLabel = "Show: Genera";
    } else if ( lifelist.listViewRankFilter === "species" ) {
      rankLabel = "Show: Species";
    } else if ( lifelist.listViewRankFilter === "leaves" ) {
      rankLabel = "Show: Leaves";
    }
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
            onClick={( ) => setNavView( lifelist.navView === "simplified" ? "tree" : "simplified" )}
          >
            SimpleTree: { lifelist.navView === "simplified" ? "on" : "off" }
          </li>
          <li
            onClick={( ) => setTreeMode( lifelist.treeMode === "list" ? "tree" : "list" )}
          >
            FocusMode: { lifelist.treeMode === "list" ? "on" : "off" }
          </li>
          <li
            disabled={lifelist.treeMode !== "list"}
            onClick={( ) => setTreeIndent( lifelist.treeIndent ? false : true )}
          >
            Indent: { lifelist.treeIndent ? "on" : "off" }
          </li>
          <li className="divider" />
          <li
            className={lifelist.listViewRankFilter === "default" ? "selected" : null}
            onClick={( ) => setListViewRankFilter( "default" )}
          >
            Children
          </li>
          { [{ filter: "kingdoms", label: "Kingdoms", rank_level: 70 },
            { filter: "phylums", label: "Phylums", rank_level: 60 },
            { filter: "classes", label: "Classes", rank_level: 50 },
            { filter: "orders", label: "Orders", rank_level: 40 },
            { filter: "families", label: "Families", rank_level: 30 },
            { filter: "genera", label: "Genera", rank_level: 20 },
            { filter: "species", label: "Species", rank_level: 10 }].map( r => (
              <li
                disabled={lifelist.listViewOpenTaxon && lifelist.listViewOpenTaxon.rank_level <= r.rank_level}
                className={lifelist.listViewRankFilter === r.filter ? "selected" : null}
                key={`rank-filter-${r.filter}`}
                onClick={e => {
                  if ( lifelist.listViewOpenTaxon && lifelist.listViewOpenTaxon.rank_level <= r.rank_level ) {
                    e.preventDefault( );
                    e.stopPropagation( );
                    return;
                  }
                  setListViewRankFilter( r.filter );
                }}
              >
                { r.label }
              </li>
          ) )}
          <li
            className={lifelist.listViewRankFilter === "leaves" ? "selected" : null}
            onClick={( ) => setListViewRankFilter( "leaves" )}
          >
            Leaves
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

  render( ) {
    const { lifelist } = this.props;
    let treeComponent;
    if ( lifelist.navView === "tree" ) {
      treeComponent = ( <TaxaTreeContainer /> );
    } else if ( lifelist.navView === "list" ) {
      treeComponent = ( <TaxaListContainer /> );
    } else {
      treeComponent = ( <TaxaTreeContainer mode="simplified" /> );
    }
    return (
      <div className="Details">
        <div className="search-options">
          { this.sortOptions( ) }
          { this.rankOptions( ) }
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
  setTreeIndent: PropTypes.func
};

export default TreeView;
