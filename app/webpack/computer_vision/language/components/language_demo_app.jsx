import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import ObservationContainer from "../containers/observation_container";
import ConfirmModalContainer from "../../../observations/show/containers/confirm_modal_container";

/* global inaturalist, SITE_ICONS, BLOG_URL */

class ComputerVisionEvalApp extends Component {
  constructor( props, context ) {
    super( props, context );
    this.state = {
      searchTerm: null,
      searchTaxon: null,
      searchTaxonID: null,
      queryModifiedSinceSearch: false,
      taxonModifiedSinceSearch: false
    };
  }

  setSearchTerm( searchTerm ) {
    this.setState( {
      searchTerm,
      queryModifiedSinceSearch: true
    } );
  }

  setSearchTaxon( searchTaxon, searchTaxonID = null ) {
    this.setState( {
      searchTaxon,
      searchTaxonID,
      taxonModifiedSinceSearch: true
    } );
  }

  performSearch( ) {
    this.props.languageSearch( this.state.searchTerm, this.state.searchTaxon );
    this.setState( {
      queryModifiedSinceSearch: false,
      taxonModifiedSinceSearch: false
    } );
  }

  // eslint-disable-next-line class-methods-use-this
  header( ) {
    return (
      <nav className="navbar navbar-default">
        <div className="container">
          <div className="navbar-header">
            <div className="logo">
              <a href="/" className="navbar-brand" title={SITE.name} alt={SITE.name}>
                <img alt="Site Logo" src={SITE.logo} />
              </a>
            </div>
            <div className="title">
              Vision Language Demo
            </div>
          </div>
        </div>
      </nav>
    );
  }

  taxonAutocomplete( ) {
    return (
      <TaxonAutocomplete
        config={this.props.config}
        bootstrapClear
        searchExternal={false}
        resetOnChange={false}
        initialSelection={this.state.searchTaxon}
        initialTaxonID={this.state.searchTaxonID}
        disabled={this.props.votingEnabled}
        afterSelect={result => {
          this.setSearchTaxon( result.item );
        }}
        afterUnselect={( ) => {
          this.setSearchTaxon( null );
        }}
      />
    );
  }

  iconicTaxaSelectors( ) {
    return (
      <div className="form-group">
        <div className={`iconic-taxa-selectors${this.props.votingEnabled ? " disabled" : ""}`}>
          { _.map( _.sortBy( inaturalist.ICONIC_TAXA, "name" ), t => {
            const selected = this.state.searchTaxon && this.state.searchTaxon.id === t.id;
            return (
              <button
                type="button"
                title={I18n.t( `all_taxa.${t.label}` )}
                className={`iconic-taxon-icon ${selected ? "selected" : ""}`}
                key={`iconic-taxon-${_.toLower( t.name )}`}
                disabled={this.props.votingEnabled}
                onClick={( ) => {
                  if ( selected ) {
                    this.setSearchTaxon( null );
                    return;
                  }
                  if ( !_.isEmpty( this.props.iconicTaxa )
                    && _.has( this.props.iconicTaxa, t.id )
                  ) {
                    this.setSearchTaxon( this.props.iconicTaxa[t.id] );
                    return;
                  }
                  this.setSearchTaxon( null, t.id );
                }}
              >
                <i
                  className={`icon-iconic-${_.toLower( t.name )}`}
                />
              </button>
            );
          } ) }
        </div>
      </div>
    );
  }

  formActionButtons( ) {
    let improveButtonText = "Help Us Improve";
    if ( this.props.votingEnabled ) {
      improveButtonText = "Cancel";
    } else if ( this.props.submissionAcknowledged ) {
      improveButtonText = "Thank you!";
    }
    const searchChanged = (
      this.state.searchTerm !== this.props.searchedTerm
    ) || this.state.queryModifiedSinceSearch;
    const taxonChanged = (
      this.state.searchTaxon !== this.props.searchedTaxon
    ) || this.state.taxonModifiedSinceSearch;
    return (
      <div className="col-md-2 action-buttons">
        <button
          type="button"
          className="btn btn btn-primary search"
          disabled={
            _.isEmpty( this.state.searchTerm )
            || this.props.votingEnabled
            || ( !searchChanged && !taxonChanged )
          }
          onClick={e => {
            this.performSearch( );
            e.target.blur( );
          }}
        >
          Search
        </button>
        <button
          type="button"
          className={`btn ${this.props.votingEnabled ? "btn-warning" : "btn-default"}`}
          disabled={this.props.searchStatus !== "done" || this.props.submissionAcknowledged}
          onClick={e => {
            this.props.toggleVoting( );
            $( e.target ).blur( );
          }}
        >
          { improveButtonText }
        </button>
      </div>
    );
  }

  searchForm( ) {
    return (
      <div className={`container search-form${this.props.votingEnabled ? " voting" : ""}`}>
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8">
            <div className="form-group">
              <label htmlFor="search_term">
                What do you want to search for?
              </label>
              <div className="search-input">
                <input
                  className="form-control"
                  name="search_term"
                  id="search_term"
                  type="text"
                  placeholder="e.g. a yellow bug with black spots"
                  disabled={this.props.votingEnabled}
                  onKeyDown={e => {
                    if ( e.keyCode === 13 ) {
                      this.performSearch( );
                      $( e.target ).blur( );
                    }
                  }}
                  onChange={e => {
                    this.setSearchTerm( e.target.value );
                  }}
                />
                { !_.isEmpty( this.state.searchTerm ) && (
                  <span
                    type="button"
                    aria-hidden="true"
                    className="glyphicon glyphicon-remove-circle searchclear"
                    onClick={( ) => {
                      $( "#search_term" ).val( "" );
                      this.setSearchTerm( null );
                    }}
                  />
                ) }
              </div>
            </div>
          </div>
          <div className="col-md-2" />
        </div>
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-6">
            { this.taxonAutocomplete( ) }
            { this.iconicTaxaSelectors( ) }
          </div>
          { this.formActionButtons( ) }
        </div>
      </div>
    );
  }

  helpImproveFlash( ) {
    if ( !this.props.votingEnabled ) {
      return null;
    }
    return (
      <div className="container">
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8">
            <div className="improve-panel">
              To help us improve this model we would like to know which of the images on this page
              are relevant to your search &quot;
              {this.props.searchedTerm}
              &quot;. Please mark each image as relevant
              <i className="fa fa-thumbs-o-up" />
              if it matches your search and not relevant
              <i className="fa fa-thumbs-o-down" />
              if it doesn&apos;t. When you are finished, please click submit.
              <div className="improve-submit">
                <button
                  className="btn btn-success"
                  type="button"
                  disabled={_.isEmpty( this.props.votes )}
                  onClick={() => {
                    this.props.submitVotes( { scrollTop: true } );
                  }}
                >
                  Submit
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  observationsGrid( ) {
    if ( this.props.searchStatus === "searching" ) {
      return (
        <div className="loading">
          <div className="loading_spinner" />
        </div>
      );
    }
    if ( _.isEmpty( this.props.searchResponse ) ) {
      return null;
    }

    return (
      <div className="container">
        <div className="row">
          <div className="col-md-12">
            <div className="ObservationsGrid" key="observations-flex-grid">
              { this.props.searchResponse.results.map( r => ( (
                <ObservationContainer
                  key={`photo-${r.photo_id}`}
                  observation={r.observation}
                  photoID={r.photo_id}
                />
              ) ) ) }
            </div>
          </div>
        </div>
      </div>
    );
  }

  votingActionButtons( options = { } ) {
    if ( _.isEmpty( this.props.searchedTerm ) || !this.props.votingEnabled ) {
      return null;
    }
    return (
      <div className="container voting-action-buttons">
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8 buttons-container">
            <button
              className="btn btn-default"
              type="button"
              onClick={( ) => this.props.voteRemainingUp( )}
            >
              Vote remaining up
              <i className="fa fa-thumbs-o-up" />
            </button>
            <button
              className="btn btn-default"
              type="button"
              onClick={( ) => this.props.voteRemainingDown( )}
            >
              Vote remaining down
              <i className="fa fa-thumbs-o-down" />
            </button>
            { options.showSubmit && (
              <button
                className="btn btn-success submit"
                type="button"
                disabled={_.isEmpty( this.props.votes )}
                onClick={e => {
                  $( e.target ).blur( );
                  this.props.submitVotes( { scrollTop: true } );
                }}
              >
                Submit
              </button>
            ) }
          </div>
        </div>
      </div>
    );
  }

  pagination( options = { } ) {
    if ( _.isEmpty( this.props.searchedTerm ) || this.props.searchStatus !== "done" ) {
      return null;
    }
    return (
      <div className="container pagination-buttons">
        <div className="row">
          <div className="col-md-12">
            <button
              className="btn btn-default previous"
              type="button"
              disabled={
                this.props.searchResponse.page === 1
                || this.props.searchStatus !== "done"
                || this.props.votingEnabled
              }
              onClick={( ) => this.props.previousPage( { scrollTop: options.scrollTop } )}
            >
              <i className="fa fa-long-arrow-left" />
            </button>
            <button
              className="btn btn-default next"
              type="button"
              disabled={
                this.props.searchResponse.page > 4
                || this.props.searchStatus !== "done"
                || this.props.votingEnabled
              }
              onClick={( ) => this.props.nextPage( { scrollTop: options.scrollTop } )}
            >
              <i className="fa fa-long-arrow-right" />
            </button>
          </div>
        </div>
        { options.showIdentify && (
          <div className="row">
            <div className="col-md-12">
              <button
                className="btn btn-default identify"
                type="button"
                onClick={( ) => this.props.viewInIdentify( )}
              >
                View these observations in Identify
              </button>
            </div>
          </div>
        ) }
      </div>
    );
  }

  // eslint-disable-next-line class-methods-use-this
  about( ) {
    const microsoftURL = "https://www.microsoft.com/en-us/research/group/ai-for-good-research-lab/overview/";
    const umassURL = "https://www.umass.edu/";
    const edinburghURL = "https://www.ed.ac.uk/";
    const mitURL = "https://www.mit.edu/";
    /* eslint-disable react/jsx-one-expression-per-line */
    return (
      <div className="container">
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8">
            <div className="about">
              <p>
                <a href="https://www.inaturalist.org">
                  iNaturalist
                </a>{" "}
                has teamed up with researchers at{" "}
                <a href={microsoftURL} target="_blank" rel="noopener noreferrer">
                  Microsoft AI for Good Lab
                </a>,{" "}
                <a href={umassURL} target="_blank" rel="noopener noreferrer">
                  University of Massachusetts
                </a>,{" "}
                <a href={edinburghURL} target="_blank" rel="noopener noreferrer">
                  University of Edinburgh
                </a>, and{" "}
                <a href={mitURL} target="_blank" rel="noopener noreferrer">
                  MIT
                </a>{" "}
                to begin exploring how Vision Language
                models can help search iNaturalist observations. This demo compares your
                text with a sample of 10 million iNaturalist photos and orders the results
                from most to least relevant.
              </p>
              <p>
                You can use this demo as a new way to find interesting iNaturalist observations
                and annotate or add them to your project.
              </p>
              <p>
                You can also use this demo to help us improve the Vision Language model behind
                this demo by telling us which of the returned images was relevant to your
                search text.
              </p>
              <p>
                This demo is using a third-party Vision Language CLIP model that was not trained
                on iNaturalist data or by the iNaturalist team. It may produce inaccurate, biased,
                or offensive results.{" "}
                <a href={BLOG_URL}>
                  Read more on the iNaturalist Blog.
                </a>
              </p>
              <div className="logos">
                <div className="logo">
                  <a href={microsoftURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.microsoft} alt="Microsoft AI for Good Lab" />
                  </a>
                </div>
                <div className="logo">
                  <a href={edinburghURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.edinburgh} alt="University of Edinburgh" />
                  </a>
                </div>
                <div className="logo">
                  <a href={umassURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.umass} alt="UMass Amherst" />
                  </a>
                </div>
                <div className="logo">
                  <a href={mitURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.mit} alt="MIT" />
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
    /* eslint-enable react/jsx-one-expression-per-line */
  }

  render( ) {
    return (
      <div className="bootstrap">
        { this.header( ) }
        { this.searchForm( ) }
        { this.helpImproveFlash( ) }
        { !this.props.votingEnabled && this.pagination( ) }
        { this.votingActionButtons( ) }
        { this.observationsGrid( ) }
        { this.votingActionButtons( { showSubmit: true } ) }
        { this.pagination( { showIdentify: true, scrollTop: true } ) }
        { this.about( ) }
        <ConfirmModalContainer
          hideCancel
          onConfirm={() => {
            this.props.acknowledgeSubmission( );
          }}
        />
      </div>
    );
  }
}

ComputerVisionEvalApp.propTypes = {
  languageSearch: PropTypes.func,
  searchResponse: PropTypes.object,
  searchStatus: PropTypes.string,
  toggleVoting: PropTypes.func,
  iconicTaxa: PropTypes.object,
  votingEnabled: PropTypes.bool,
  searchedTerm: PropTypes.string,
  searchedTaxon: PropTypes.object,
  votes: PropTypes.object,
  submitVotes: PropTypes.func,
  nextPage: PropTypes.func,
  previousPage: PropTypes.func,
  voteRemainingUp: PropTypes.func,
  voteRemainingDown: PropTypes.func,
  viewInIdentify: PropTypes.func,
  submissionAcknowledged: PropTypes.bool,
  acknowledgeSubmission: PropTypes.func,
  config: PropTypes.object
};

export default ComputerVisionEvalApp;
