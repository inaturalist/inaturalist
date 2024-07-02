import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import ReactDOMServer from "react-dom/server";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import ObservationContainer from "../containers/observation_container";
import ConfirmModalContainer from "../../../observations/show/containers/confirm_modal_container";

/* global inaturalist, SITE_ICONS */
/* eslint react/no-danger: 0 */

class ComputerVisionEvalApp extends Component {
  constructor( props, context ) {
    super( props, context );
    this.state = {
      searchTerm: this.props.initialQuery,
      searchTaxon: null,
      queryModifiedSinceSearch: false,
      taxonModifiedSinceSearch: false
    };
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.initialQuery !== this.props.initialQuery ) {
      $( "#search_term" ).val( this.props.initialQuery );
      this.setSearchTerm( this.props.initialQuery, { modified: false } );
    }
    if ( prevProps.initialTaxon !== this.props.initialTaxon
    ) {
      this.setSearchTaxon( this.props.initialTaxon, { modified: false } );
    }
  }

  setSearchTerm( searchTerm, options = { } ) {
    this.setState( {
      searchTerm,
      queryModifiedSinceSearch: options.modified !== false
    } );
  }

  setSearchTaxon( searchTaxon, options = { } ) {
    if ( searchTaxon
      && !_.isEmpty( this.props.iconicTaxa )
      && _.has( this.props.iconicTaxa, searchTaxon.id )
    ) {
      searchTaxon = this.props.iconicTaxa[searchTaxon.id];
    }
    this.setState( {
      searchTaxon,
      taxonModifiedSinceSearch: options.modified !== false
    } );
  }

  performSearch( ) {
    this.props.languageSearch( this.state.searchTerm, this.state.searchTaxon );
    this.setState( {
      queryModifiedSinceSearch: false,
      taxonModifiedSinceSearch: false
    } );
  }

  performExampleSearch( searchTerm, taxonID ) {
    $( "#search_term" ).val( searchTerm );
    this.setSearchTerm( searchTerm );
    this.setSearchTaxon( { id: taxonID } );
    setTimeout( ( ) => {
      this.performSearch( );
    } );
  }

  reset( ) {
    $( "#search_term" ).val( "" );
    this.setState( {
      searchTerm: null,
      searchTaxon: null,
      queryModifiedSinceSearch: true,
      taxonModifiedSinceSearch: true
    } );
    this.props.resetState( );
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
              <a
                href="/vision_language_demo"
                onClick={e => {
                  e.preventDefault( );
                  this.reset( );
                }}
              >
                { I18n.t( "views.nls_demo.vision_language_demo" ) }
              </a>
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
        placeholder={I18n.t( "filter_by_species" )}
        initialSelection={this.state.searchTaxon && this.state.searchTaxon.name
          ? this.state.searchTaxon : null}
        initialTaxonID={this.state.searchTaxon && !this.state.searchTaxon.name
          ? this.state.searchTaxon.id : null}
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
                  this.setSearchTaxon( { id: t.id } );
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
    let improveButtonText = I18n.t( "views.nls_demo.help_us_improve" );
    if ( this.props.votingEnabled ) {
      improveButtonText = I18n.t( "cancel" );
    } else if ( this.props.submissionAcknowledged ) {
      improveButtonText = I18n.t( "thank_you!" );
    }
    const searchChanged = (
      this.state.searchTerm !== this.props.searchedTerm
    ) || this.state.queryModifiedSinceSearch;
    const taxonChanged = (
      ( this.state.searchTaxon && this.state.searchTaxon.id )
      !== ( this.props.searchedTaxon && this.props.searchedTaxon.id )
    ) || this.state.taxonModifiedSinceSearch;
    return (
      <div className="col-md-2 action-buttons">
        <button
          type="button"
          className="btn btn-primary search"
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
                { I18n.t( "views.nls_demo.what_do_you_want_to_search_for" ) }
              </label>
              <div className="search-input">
                <input
                  className="form-control"
                  name="search_term"
                  id="search_term"
                  type="text"
                  placeholder={I18n.t(
                    "views.nls_demo.for_example_query", {
                      query_in_english: "A yellow bug with black spots"
                  } )}
                  disabled={this.props.votingEnabled}
                  autoComplete="off"
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
              <div
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.nls_demo.to_help_us_improve", {
                    searched_term: this.props.searchedTerm,
                    thumbs_up_icon: ReactDOMServer.renderToString(
                      <i className="fa fa-thumbs-o-up" />
                    ),
                    thumbs_down_icon: ReactDOMServer.renderToString(
                      <i className="fa fa-thumbs-o-down" />
                    )
                  } )
                }}
              />
              <div className="improve-submit">
                <button
                  className="btn btn-success"
                  type="button"
                  disabled={_.isEmpty( this.props.votes )}
                  onClick={() => {
                    this.props.submitVotes( { scrollTop: true } );
                  }}
                >
                  { I18n.t( "submit" ) }
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
              { I18n.t( "views.nls_demo.mark_remaining_as_relevant" ) }
              <i className="fa fa-thumbs-o-up" />
            </button>
            <button
              className="btn btn-default"
              type="button"
              onClick={( ) => this.props.voteRemainingDown( )}
            >
              { I18n.t( "views.nls_demo.mark_remaining_as_not_relevant" ) }
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
                { I18n.t( "submit" ) }
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
              title={I18n.t( "previous_page" )}
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
              title={I18n.t( "next_page" )}
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
                { I18n.t( "views.nls_demo.view_these_observations_in_identify" ) }
              </button>
            </div>
          </div>
        ) }
      </div>
    );
  }

  exampleSearches( ) {
    if ( !_.isEmpty( this.props.searchedTerm ) ) {
      return null;
    }
    const exampleSearches = [{
      searchTerm: "A bird eating fruit",
      searchTaxonID: 3
    }, {
      searchTerm: "A houseplant in a pot",
      searchTaxonID: 47126
    }, {
      searchTerm: "Mating dragonflies",
      searchTaxonID: 47792
    }, {
      searchTerm: "Un poisson tropical avec des couleurs vives",
      searchTaxonID: 47178
    }, {
      searchTerm: "Drinking at a waterhole"
    }];
    return (
      <div className="container">
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8">
            <div className="example-searches-panel">
              { I18n.t( "views.nls_demo.try_one_of_these_example_searches_colon" ) }
              <ul>
                { _.map( exampleSearches, ( exampleSearch, index ) => {
                  let href = `/vision_language_demo?q=${exampleSearch.searchTerm.replace( / /g, "+" )}`;
                  if ( exampleSearch.searchTaxonID ) {
                    href += `&taxon_id=${exampleSearch.searchTaxonID}`;
                  }
                  return (
                    <li key={`example-search-${index}`}>
                      <a
                        href={href}
                        onClick={e => {
                          e.preventDefault( );
                          this.performExampleSearch(
                            exampleSearch.searchTerm,
                            exampleSearch.searchTaxonID
                          );
                        }}
                      >
                        { exampleSearch.searchTerm }
                      </a>
                    </li>
                  );
                } ) }
              </ul>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // eslint-disable-next-line class-methods-use-this
  about( ) {
    const microsoftURL = "https://www.microsoft.com/en-us/research/group/ai-for-good-research-lab/overview/";
    const umassURL = "https://www.cics.umass.edu/people/van-horn-grant";
    const edinburghURL = "https://www.inf.ed.ac.uk/people/staff/Oisin_Mac_Aodha.html";
    const mitURL = "https://www.eecs.mit.edu/people/sara-beery/";
    const uclURL = "https://www.ucl.ac.uk/";
    return (
      <div className="container">
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8">
            <div className="about">
              <p
                dangerouslySetInnerHTML={{ __html: I18n.t( "views.nls_demo.inaturalist_has_teamed" ) }}
              />
              <p
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "views.nls_demo.this_demo_tool3", {
                    url: "/vision_language_demo?q=a+bird+eating+fruit&taxon_id=3",
                    query_in_english: "a bird eating fruit"
                  } )
                }}
              />
              <p
                dangerouslySetInnerHTML={{ __html: I18n.t( "views.nls_demo.you_can_also_use_this_demo" ) }}
              />
              <div className="logos">
                <div className="logo">
                  <a href={umassURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.umass} alt="UMass Amherst" />
                  </a>
                </div>
                <div className="logo">
                  <a href={edinburghURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.edinburgh} alt="University of Edinburgh" />
                  </a>
                </div>
                <div className="logo">
                  <a href={uclURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.ucl} alt="University College London" />
                  </a>
                </div>
                <div className="logo">
                  <a href={mitURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.mit} alt="Massachusetts Institute of Technology" />
                  </a>
                </div>
                <div className="logo">
                  <a href={microsoftURL} target="_blank" rel="noopener noreferrer">
                    <img src={SITE_ICONS.microsoft} alt="Microsoft AI for Good Lab" />
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="row">
          <div className="col-md-2" />
          <div className="col-md-8">
            <div className="support">
              <p>
                { I18n.t( "views.nls_demo.if_youd_like_to_support_this_work" ) }
              </p>
              <a
                href="https://www.inaturalist.org/donate?utm_campaign=nls-demo&utm_medium=web&utm_source=inaturalist.org&utm_content=button&utm_term=donate-to-inaturalist"
                target="_blank"
                rel="noopener noreferrer"
              >
                <button
                  type="button"
                  className="btn btn-success btn-lg"
                >
                  { I18n.t( "donate_to_inaturalist" ) }
                </button>
              </a>
            </div>
          </div>
        </div>
      </div>
    );
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
        { this.exampleSearches( ) }
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
  resetState: PropTypes.func,
  initialQuery: PropTypes.string,
  initialTaxon: PropTypes.object,
  config: PropTypes.object
};

export default ComputerVisionEvalApp;
