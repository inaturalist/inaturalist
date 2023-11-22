import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
import inaturalistjs from "inaturalistjs";
import { Glyphicon } from "react-bootstrap";
import { updateSession } from "../../../shared/util";

let searchInProgress;

const TAXON_FIELDS = {
  ancestor_ids: true,
  default_photo: {
    square_url: true
  },
  iconic_taxon_id: true,
  iconic_taxon_name: true,
  is_active: true,
  matched_term: true,
  name: true,
  preferred_common_name: true,
  rank: true,
  rank_level: true
};

class TaxonAutocomplete extends React.Component {
  static differentMatchedTerm( result, fieldValue ) {
    if ( !result.matched_term ) { return false; }
    if (
      _.includes( result.title, fieldValue )
      || _.includes( result.subtitle, fieldValue )
    ) {
      return false;
    }
    if (
      _.includes( result.title, result.matched_term )
      || _.includes( result.subtitle, result.matched_term )
    ) {
      return false;
    }
    return ` (${result.matched_term})`;
  }

  static itemPhoto( r ) {
    if ( r.default_photo ) {
      return ( <img alt="thumbnail" src={r.default_photo.square_url} /> );
    }
    return null;
  }

  static itemIcon( r ) {
    const name = _.isFunction( r.iconicTaxonName )
      ? r.iconicTaxonName( ).toLowerCase( )
      : "unknown";
    return ( <i className={`icon icon-iconic-${name}`} /> );
  }

  static placeholderTemplate( string ) {
    return ReactDOMServer.renderToString(
      <div className="ac ac-message" data-type="placeholder">
        <div className="ac-thumb">
          <Glyphicon glyph="search" />
        </div>
        <div className="ac-label">
          <span
            className="title"
            dangerouslySetInnerHTML={{
              __html: I18n.t( "use_name_as_a_placeholder", { name: string } )
            }}
          />
          <span className="subtitle" />
        </div>
      </div>
    );
  }

  static searchExternalTemplate( ) {
    return ReactDOMServer.renderToString(
      <div className="ac ac-message" data-type="search_external">
        <div className="ac-thumb">
          <Glyphicon glyph="search" />
        </div>
        <div className="ac-label">
          <span className="title linky">
            { I18n.t( "search_external_name_providers" ) }
          </span>
        </div>
      </div>
    );
  }

  static resultTemplate( r ) {
    if ( r.type === "placeholder" ) {
      return TaxonAutocomplete.placeholderTemplate( r.title );
    }
    if ( r.type === "search_external" ) {
      return TaxonAutocomplete.searchExternalTemplate( );
    }
    const photo = TaxonAutocomplete.itemPhoto( r ) || TaxonAutocomplete.itemIcon( r );
    let className = "ac";
    let extraSubtitle;
    if ( r.isVisionResult ) {
      className += " vision";
      const subtitles = [];
      if ( r.visionScore ) {
        subtitles.push( I18n.t( "visually_similar" ) );
      }
      if ( r.frequencyScore ) {
        subtitles.push( I18n.t( "expected_nearby" ) );
      }
      extraSubtitle = ( <span className="subtitle vision">{ subtitles.join( " / " ) }</span> );
    }
    return ReactDOMServer.renderToString(
      <div className={className} data-taxon-id={r.id}>
        <div className="ac-thumb has-photo">
          { photo }
        </div>
        <div className="ac-label">
          <div>
            <span className="title">{ r.title }</span>
            <span className="subtitle">{ r.subtitle }</span>
            { extraSubtitle }
          </div>
        </div>
        { r.type !== "message" && (
          <a target="_blank" rel="noopener noreferrer" href={`/taxa/${r.id}`} className="ac-view">
            { I18n.t( "view" ) }
          </a>
        ) }
      </div>
    );
  }

  constructor( props, context ) {
    super( props, context );
    this.source = this.source.bind( this );
    this.select = this.select.bind( this );
    this.fetchTaxon = this.fetchTaxon.bind( this );
    this.idElement = this.idElement.bind( this );
    this.inputElement = this.inputElement.bind( this );
    this.inputValue = this.inputValue.bind( this );
    this.template = this.template.bind( this );
    this.resultTemplate = TaxonAutocomplete.resultTemplate.bind( this );
    this.placeholderTemplate = TaxonAutocomplete.placeholderTemplate.bind( this );
    this.searchExternalTemplate = TaxonAutocomplete.searchExternalTemplate.bind( this );
    this.searchExternalElement = this.searchExternalElement.bind( this );
    this.thumbnailElement = this.thumbnailElement.bind( this );
    this.autocomplete = this.autocomplete.bind( this );
    this.updateWithSelection = this.updateWithSelection.bind( this );
    const { config } = props;
    const { currentUser } = ( config || {} );
    this.state = {
      viewNotNearby: currentUser && currentUser.prefers_not_nearby_suggestions,
      // eslint-disable-next-line react/no-unused-state
      numNearby: 0
    };
  }

  componentDidMount( ) {
    const {
      afterUnselect,
      initialSelection
    } = this.props;
    const that = this;
    const getState = ( ) => that.state;
    const setState = updates => that.setState( updates );
    const renderMenuWithCategories = function ( ul, items ) {
      ul.removeClass( "ui-corner-all" ).removeClass( "ui-menu" );
      ul.addClass( "ac-menu" );
      if ( items.length === 1 && items[0].label === "loadingSuggestions" ) {
        ul.append( `<li class="category non-option">${I18n.t( "loading_suggestions" )}</li>` );
        return;
      }
      if ( items.length === 1 && items[0].label === "noResults" ) {
        ul.append(
          $( "<li />" ).addClass( "category non-option" ).text(
            I18n.t( "not_confident" )
          )
        );
        return;
      }
      const isVisionResults = items[0] && items[0].isVisionResult;
      let commonAncestorCategoryShown = false;
      let suggestionsCategoryShown = false;
      let experimantalWarningShown = false;
      $.each( items, ( index, item ) => {
        if ( isVisionResults ) {
          if ( item.isExperimental && !experimantalWarningShown ) {
            ul.append( `<li class='non-option warning'>Experimental: ${item.isExperimental}</li>` );
            experimantalWarningShown = true;
          }
          if ( item.isCommonAncestor ) {
            const snakeCaseRank = _.snakeCase( item.rank );
            // Note: given the way we're doing fallbacks as of this writing on
            // 2021-08-10, `defaultValue` only kicks in when the key doesn't
            // exist in the current locale or any of the fallbacks... so if
            // there's an English translation, that will be used instead of
            // `defaultValue`. Here I'm achieving the desired behavior
            // manually, but this is a problem with our fallback system, b/c
            // this is *not* how defaultValue is supposed to work.
            // I18n.t( "were_pretty_sure_this_is_in_the_genus" )
            // I18n.t( "were_pretty_sure_this_is_in_the_family" )
            // I18n.t( "were_pretty_sure_this_is_in_the_order" )
            const labelInEnglish = I18n.t( `were_pretty_sure_this_is_in_the_${snakeCaseRank}`, { locale: "en" } );
            const labelInLocaleFallback = I18n.t( "were_pretty_sure_this_is_in_the_rank", {
              rank: I18n.t( `ranks_lowercase_${snakeCaseRank}`, { defaultValue: item.rank } ),
              gender: snakeCaseRank,
              iconic_taxon: item.iconic_taxon_name
            } );
            const labelInLocale = I18n.t( `were_pretty_sure_this_is_in_the_${snakeCaseRank}`, {
              defaultValue: labelInLocaleFallback,
              iconic_taxon: item.iconic_taxon_name
            } );
            let label = labelInLocale;
            if ( I18n.locale !== "en" && label === labelInEnglish ) {
              label = labelInLocaleFallback;
            }
            ul.append( `<li class='category header-category non-option'>${label}</li>` );
            commonAncestorCategoryShown = true;
          } else if ( !suggestionsCategoryShown ) {
            let label = I18n.t( "here_are_our_top_species_suggestions" );
            label = commonAncestorCategoryShown
              ? I18n.t( "here_are_our_top_suggestions" )
              : I18n.t( "not_confident_top_suggestions" );
            ul.append( `<li class='category header-category non-option'>${label}</li>` );
            suggestionsCategoryShown = true;
          }
        }
        this._renderItemData( ul, item );
      } );
      const query = that.inputElement( ).val( );
      const manualQuery = query && query.length >= 0;
      const { numNearby, numSuggested, viewNotNearby } = getState( );
      if ( !manualQuery && numNearby > 0 && numNearby !== numSuggested ) {
        const nearbyToggle = $( "<button />" ).attr( "type", "button" )
          .append(
            viewNotNearby
              ? I18n.t( "only_view_nearby_suggestions" )
              : I18n.t( "include_suggestions_not_expected_nearby" )
          )
          .click( e => {
            e.preventDefault( );
            const { viewNotNearby: innerViewNotNearby } = getState( );
            $( e.target ).text(
              innerViewNotNearby
                ? I18n.t( "include_suggestions_not_expected_nearby" )
                : I18n.t( "only_view_nearby_suggestions" )
            );
            setState( { viewNotNearby: !innerViewNotNearby } );
            updateSession( { prefers_not_nearby_suggestions: !innerViewNotNearby } );
            that.inputElement( ).autocomplete( "search" );
            return false;
          } );
        ul.append(
          $( "<li />" ).addClass( "non-option nearby-toggle" ).append( nearbyToggle )
        );
      }
    };
    const opts = {
      ...this.props,
      extraClass: "taxon",
      idEl: this.idElement( ),
      source: this.source,
      select: this.select,
      template: this.template,
      // ensure the AC menu scrolls with the input
      appendTo: this.idElement( ).parent( ),
      minLength: 0,
      renderMenu: renderMenuWithCategories,
      menuClass: "taxon-autocomplete",
      position: {
        collision: "flip none"
      }
    };
    this.inputElement( ).genericAutocomplete( opts );
    this.fetchTaxon( );
    this.inputElement( ).bind( "assignSelection", ( e, t, options ) => {
      if ( !t.title ) {
        t.title = this.resultTitle( t );
      }
      this.updateWithSelection( t, options );
    } );
    this.inputElement( ).unbind( "resetSelection" );
    this.inputElement( ).bind( "resetSelection", ( ) => {
      if ( this.idElement( ).val( ) ) {
        this.thumbnailElement( ).css( { "background-image": "none" } );
        this.thumbnailElement( ).html(
          ReactDOMServer.renderToString( ( <Glyphicon glyph="search" /> ) )
        );
        this.idElement( ).val( null );
        if ( afterUnselect ) { afterUnselect( ); }
      }
      if ( this._mounted ) {
        this.inputElement( ).selection = null;
      }
    } );
    if ( initialSelection ) {
      this.inputElement( ).trigger( "assignSelection", [initialSelection, { initial: true }] );
    }
    this._mounted = true;
  }

  componentDidUpdate( prevProps ) {
    const { initialTaxonID, visionParams } = this.props;
    if (
      initialTaxonID
      && initialTaxonID !== prevProps.initialTaxonID
    ) {
      this.fetchTaxon( );
    }
    if ( !_.isEqual( visionParams, prevProps.visionParams ) ) {
      this.cachedVisionResponse = null;
    }
  }

  componentWillUnmount( ) {
    this.inputElement( ).unbind( );
    // The following unpleasantness is brought to you by the fact that the
    // unbind() call above doesn't actually seem to unbind the resetSelection
    // callback bound in componentDidMount. I tried various other ways of
    // unbinding, but no luck.
    // https://facebook.github.io/react/blog/2015/12/16/ismounted-antipattern.html
    this._mounted = false;
    this.inputElement( ).autocomplete( "destroy" );
  }

  returnVisionResults( response, callback ) {
    let { results } = response;
    const { viewNotNearby } = this.state;
    const nearbyResults = _.filter(
      response.results,
      r => r.frequency_score && r.frequency_score > 0
    );
    this.setState( {
      // eslint-disable-next-line react/no-unused-state
      numSuggested: response.results.length,
      // eslint-disable-next-line react/no-unused-state
      numNearby: nearbyResults.length
    } );
    if ( nearbyResults.length > 0 && !viewNotNearby ) {
      results = nearbyResults;
    }
    const visionTaxa = _.map( results.slice( 0, 8 ), r => {
      const taxon = new iNatModels.Taxon( r.taxon );
      taxon.isVisionResult = true;
      taxon.visionScore = r.vision_score;
      taxon.frequencyScore = r.frequency_score;
      taxon.isExperimental = response.experimental;
      return taxon;
    } );
    if ( response.common_ancestor ) {
      const taxon = new iNatModels.Taxon( response.common_ancestor.taxon );
      taxon.isVisionResult = true;
      taxon.isCommonAncestor = true;
      taxon.isExperimental = response.experimental;
      visionTaxa.unshift( taxon );
    }
    if ( visionTaxa.length === 0 ) {
      callback( ["noResults"] );
    } else {
      callback( visionTaxa );
    }
  }

  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='taxon_name']", domNode );
  }

  inputValue( ) {
    return this.inputElement( ).val( );
  }

  idElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='taxon_id']", domNode );
  }

  searchExternalElement( ) {
    return $( ".ac[data-type='search_external']", this.autocomplete( ).menu.element );
  }

  thumbnailElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( ".ac-select-thumb", domNode );
  }

  autocomplete( ) {
    return this.inputElement( ).data( "uiAutocomplete" );
  }

  fetchTaxon( ) {
    const { initialTaxonID } = this.props;
    if ( initialTaxonID ) {
      inaturalistjs.taxa.fetch( initialTaxonID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateTaxon( { taxon: r.results[0] } );
        }
      } );
    }
  }

  updateTaxon( options = { } ) {
    if ( options.taxon ) {
      this.inputElement( ).trigger( "assignSelection", options.taxon );
    }
  }

  updateWithSelection( item, options = { } ) {
    const { onSelectReturn, afterSelect, noThumbnail } = this.props;
    if ( onSelectReturn ) {
      onSelectReturn( { item } );
      return;
    }
    // show the best name in the search field
    if ( item.id ) {
      const displayName = item.title || item.name;
      this.inputElement( ).val( _.first( displayName.split( " · " ) ) );
    }
    // set the hidden taxon_id
    this.idElement( ).val( item.id );
    // set the selection's thumbnail image
    if ( !noThumbnail ) {
      if ( item.default_photo ) {
        this.thumbnailElement( ).css( {
          "background-image": `url('${item.default_photo.square_url}')`,
          "background-repeat": "no-repeat",
          "background-size": "cover",
          "background-position": "center"
        } );
        this.thumbnailElement( ).html( "" );
      } else {
        this.thumbnailElement( ).css( { "background-image": "none" } );
        this.thumbnailElement( ).html(
          ReactDOMServer.renderToString( TaxonAutocomplete.itemIcon( item ) )
        );
      }
    }
    this.inputElement( ).selection = item;
    if ( afterSelect && !options.initial ) { afterSelect( { item } ); }
  }

  visionAutocompleteSource( callback ) {
    const { config, visionParams } = this.props;
    if ( this.cachedVisionResponse ) {
      this.returnVisionResults( this.cachedVisionResponse, callback );
    } else if ( visionParams ) {
      const baseParams = config.testingApiV2
        ? {
          fields: {
            frequency_score: true,
            vision_score: true,
            taxon: TAXON_FIELDS
          }
        }
        : {};
      const viewerIsAdmin = config.currentUser && config.currentUser.roles
        && config.currentUser.roles.indexOf( "admin" ) >= 0;
      if ( viewerIsAdmin && config.testFeature ) {
        baseParams.test_feature = config.testFeature;
      }
      if ( visionParams.image ) {
        inaturalistjs.computervision.score_image( Object.assign( baseParams, visionParams ) )
          .then( r => {
            this.cachedVisionResponse = r;
            this.returnVisionResults( r, callback );
          } ).catch( e => {
            console.log( ["Error fetching vision response for photo", e] );
          } );
        callback( ["loadingSuggestions"] );
      } else if ( visionParams.observationID || visionParams.observationUUID ) {
        let { observationID, observationUUID } = visionParams;
        if ( config.testingApiV2 && observationUUID ) {
          observationID = observationUUID;
        }
        const params = Object.assign( baseParams, { id: observationID } );
        inaturalistjs.computervision.score_observation( params ).then( r => {
          this.cachedVisionResponse = r;
          this.returnVisionResults( r, callback );
        } ).catch( e => {
          console.log( ["Error fetching vision response for observation", e] );
        } );
        callback( ["loadingSuggestions"] );
      }
    }
  }

  taxonAutocompleteSource( request, callback ) {
    const {
      perPage, searchExternal, showPlaceholder, notIDs, observedByUserID, config
    } = this.props;
    const searchExternalEnabled = searchExternal
      // eslint-disable-next-line no-undef
      && ( typeof ( CONFIG ) === "undefined" || !CONFIG.content_freeze_enabled );
    const params = {
      q: request.term,
      per_page: perPage || 10,
      locale: I18n.locale,
      preferred_place_id: PREFERRED_PLACE ? PREFERRED_PLACE.id : null
    };
    if ( notIDs ) {
      params.not_id = notIDs.slice( 0, 750 ).join( "," );
    }
    if ( observedByUserID ) {
      params.observed_by_user_id = observedByUserID;
    }
    if ( config && config.testingApiV2 ) {
      params.fields = TAXON_FIELDS;
    }
    inaturalistjs.taxa.autocomplete( params ).then( r => {
      const results = r.results || [];
      // show as the last item an option to search external name providers
      if ( searchExternalEnabled !== false ) {
        results.push( {
          type: "search_external",
          title: I18n.t( "search_external_name_providers" )
        } );
      }
      if (
        showPlaceholder
        && !this.idElement( ).val( )
        && this.inputValue( )
      ) {
        results.unshift( {
          id: 0,
          type: "placeholder",
          title: this.inputValue( )
        } );
      }
      callback( _.map( results, t => new iNatModels.Taxon( t ) ) );
    } );
  }

  source( request, callback ) {
    if ( !request.term ) {
      this.visionAutocompleteSource( callback );
    } else if ( request.term ) {
      this.taxonAutocompleteSource( request, callback );
    }
  }

  select( e, ui ) {
    // clicks on the View link should not count as selection
    if ( e.toElement && $( e.toElement ).hasClass( "ac-view" ) ) {
      return false;
    }
    const { perPage, showPlaceholder } = this.props;
    // they selected the search external name provider option
    if ( ui.item.type === "search_external" && this.inputValue( ) ) {
      // set up an unique ID for this AJAX call to prevent conflicts
      const thisSearch = Math.random();
      searchInProgress = thisSearch;
      // replace 'search external' with a loading indicator
      const externalItem = this.searchExternalElement( );
      externalItem.find( ".title" ).removeClass( "linky" );
      externalItem.find( ".title" ).text( I18n.t( "loading" ) );
      externalItem.closest( "li" ).removeClass( "active" );
      externalItem.attr( "data-type", "message" );
      $.ajax( {
        url: `/taxa/search.json?per_page=${perPage}&include_external=1&partial=elastic&q=${this.inputValue( )}`,
        dataType: "json",
        success: d => {
          // if we just returned from the most recent external search
          if ( searchInProgress === thisSearch ) {
            searchInProgress = false;
            this.autocomplete( ).menu.element.empty( );
            let data = d;
            data = _.map( data, r => {
              const t = new iNatModels.Taxon( r );
              t.preferred_common_name = t.preferredCommonName( iNaturalist.localeParams( ) );
              return t;
            } );
            if ( data.length === 0 ) {
              data.push( {
                type: "message",
                title: I18n.t( "no_results_found" )
              } );
            }
            if ( showPlaceholder && this.inputValue( ) ) {
              data.unshift( {
                id: 0,
                type: "placeholder",
                title: this.inputValue( )
              } );
            }
            this.autocomplete( )._suggest( data );
            this.inputElement( ).focus( );
          }
        },
        error: () => {
          searchInProgress = false;
        }
      } );
      // this is the hacky way I'm preventing autocomplete from closing
      // the result list while the external search is happening
      this.autocomplete( ).keepOpen = true;
      setTimeout( ( ) => { this.autocomplete( ).keepOpen = false; }, 10 );
      e.preventDefault( );
      return false;
    }
    this.updateWithSelection( ui.item );
    return false;
  }

  resultTitle( result ) {
    const { config } = this.props;
    let { name } = result;
    if ( !(
      config
      && config.currentUser
      && config.currentUser.prefers_scientific_name_first
    ) ) {
      if ( !_.isEmpty( result.preferred_common_names ) ) {
        const names = _.map( result.preferred_common_names, taxonName => (
          iNatModels.Taxon.titleCaseName( taxonName.name )
        ) );
        name = names.join( " · " );
      } else {
        name = iNatModels.Taxon.titleCaseName( result.preferred_common_name ) || result.name;
      }
    }
    return name;
  }

  template( r, fieldValue, options = {} ) {
    const { config } = this.props;
    const result = _.clone( r );
    const scinameFirst = (
      config
      && config.currentUser
      && config.currentUser.prefers_scientific_name_first
    );
    if ( !result.title ) {
      result.title = this.resultTitle( result );
      r.title = result.title;
      if ( scinameFirst && result.rank_level <= 20
      ) {
        result.title = ( <i>{ result.title }</i> );
      }
    }
    if ( result.title ) {
      if ( scinameFirst ) {
        if ( !_.isEmpty( result.preferred_common_names ) ) {
          const names = _.map( result.preferred_common_names, taxonName => (
            iNatModels.Taxon.titleCaseName( taxonName.name )
          ) );
          result.subtitle = names.join( " · " );
        } else {
          result.subtitle = iNatModels.Taxon.titleCaseName( result.preferred_common_name );
        }
      }
      if ( !result.subtitle && result.name !== result.title ) {
        if ( result.rank_level <= 20 ) {
          result.subtitle = ( <i>{result.name}</i> );
        } else {
          result.subtitle = result.name;
        }
      }
    }
    const addition = TaxonAutocomplete.differentMatchedTerm( r, fieldValue );
    if ( addition ) {
      result.title = (
        <span>
          { result.title }
          { " " }
          { addition }
        </span>
      );
    }
    if ( result.rank && ( result.rank_level > 10 || !result.subtitle ) ) {
      const rank = I18n.t( `ranks.${result.rank}`, { defaultValue: result.rank } );
      result.subtitle = (
        <span>
          { rank }
          { " " }
          { result.subtitle }
        </span>
      );
    }
    return TaxonAutocomplete.resultTemplate( result, fieldValue, options );
  }

  render( ) {
    const {
      small,
      value,
      onChange,
      placeholder,
      onKeyDown
    } = this.props;
    const smallClass = small ? "input-sm" : "";
    return (
      <div className="form-group TaxonAutocomplete">
        <input type="hidden" name="taxon_id" />
        <div className={`ac-chooser input-group ${small && "small"}`}>
          <div className={`ac-select-thumb input-group-addon ${smallClass}`}>
            <Glyphicon glyph="search" />
          </div>
          <input
            type="text"
            name="taxon_name"
            value={value}
            className={`form-control ${smallClass}`}
            onChange={onChange}
            placeholder={placeholder || I18n.t( "species_name_cap" )}
            autoComplete="off"
            onKeyDown={onKeyDown}
          />
          <Glyphicon
            className="searchclear"
            glyph="remove-circle"
            onClick={() => this.inputElement( ).trigger( "resetAll" )}
          />
        </div>
      </div>
    );
  }
}

TaxonAutocomplete.propTypes = {
  onChange: PropTypes.func,
  small: PropTypes.bool,
  placeholder: PropTypes.string,
  // eslint-disable-next-line react/no-unused-prop-types
  resetOnChange: PropTypes.bool,
  searchExternal: PropTypes.bool,
  showPlaceholder: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  allowPlaceholders: PropTypes.bool,
  noThumbnail: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  onSelectReturn: PropTypes.func,
  value: PropTypes.string,
  visionParams: PropTypes.object,
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  notIDs: PropTypes.array,
  observedByUserID: PropTypes.number,
  perPage: PropTypes.number,
  config: PropTypes.object,
  onKeyDown: PropTypes.func
};

export default TaxonAutocomplete;
