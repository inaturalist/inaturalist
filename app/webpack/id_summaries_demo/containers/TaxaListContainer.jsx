import React, { Component } from "react";
import { connect } from "react-redux";
import PropTypes from "prop-types";
import { fetchTaxa } from "../actions/taxa";
import TaxaList from "../components/TaxaList";

class TaxaListContainer extends Component {
  componentDidMount() {
    this.props.fetchTaxa( { active: true } );
  }

  componentDidUpdate( prev ) {
    const { list, onLoaded } = this.props;
    if ( prev.list !== list && typeof onLoaded === "function" && list.length ) {
      onLoaded( list );
    }
  }

  render() {
    const {
      list, loading, error, images, selectedId, onTileClick
    } = this.props;
    return (
      <TaxaList
        list={list}
        images={images}
        selectedId={selectedId}
        loading={loading}
        error={error}
        onTileClick={onTileClick}
      />
    );
  }
}

TaxaListContainer.propTypes = {
  list: PropTypes.arrayOf( PropTypes.shape( {
    id: PropTypes.number,
    name: PropTypes.string,
    taxonGroup: PropTypes.string,
    photoSquareUrl: PropTypes.string
  } ) ),
  loading: PropTypes.bool,
  error: PropTypes.string,
  images: PropTypes.objectOf( PropTypes.string ),
  selectedId: PropTypes.number,
  onTileClick: PropTypes.func,
  onLoaded: PropTypes.func,
  fetchTaxa: PropTypes.func.isRequired
};

const mapState = state => ( {
  list: state.taxa.list,
  loading: state.taxa.loading,
  error: state.taxa.error
} );

export default connect( mapState, { fetchTaxa } )( TaxaListContainer );
