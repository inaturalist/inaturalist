import React, { Component } from "react";
import { connect } from "react-redux";
import PropTypes from "prop-types";
import { fetchTaxa } from "../actions/taxa";
import TaxaList from "../components/TaxaList";

class TaxaListContainer extends Component {
  componentDidMount() {
    this.fetchWithFilters();
  }

  componentDidUpdate( prev ) {
    const {
      list,
      onLoaded,
      activeOnly,
      runName
    } = this.props;
    if (
      prev.activeOnly !== activeOnly
      || prev.runName !== runName
      || prev.language !== this.props.language
    ) {
      this.fetchWithFilters();
    }
    if ( prev.list !== list && typeof onLoaded === "function" && list.length ) {
      onLoaded( list );
    }
  }

  fetchWithFilters() {
    const {
      fetchTaxa,
      activeOnly,
      runName,
      perPage,
      language
    } = this.props;
    const params = { per_page: perPage };
    if ( language ) {
      params.language = language;
    }
    if ( activeOnly ) {
      params.active = true;
    } else {
      if ( !runName ) {
        return;
      }
      params.run_name = runName;
    }
    fetchTaxa( params );
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
  fetchTaxa: PropTypes.func.isRequired,
  activeOnly: PropTypes.bool,
  runName: PropTypes.string,
  perPage: PropTypes.number,
  language: PropTypes.string
};

TaxaListContainer.defaultProps = {
  activeOnly: true,
  runName: null,
  perPage: 200,
  language: "en"
};

const mapState = state => ( {
  list: state.taxa.list,
  loading: state.taxa.loading,
  error: state.taxa.error
} );

export default connect( mapState, { fetchTaxa } )( TaxaListContainer );
