import _ from "lodash";
import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
import inaturalistjs from "inaturalistjs";
import { Glyphicon } from "react-bootstrap";
var searchInProgress;
/* global iNatModels */

class TaxonAutocomplete extends React.Component {

  constructor( props, context ) {
    super( props, context );
    this.source = this.source.bind( this );
    this.select = this.select.bind( this );
    this.fetchTaxon = this.fetchTaxon.bind( this );
    this.idElement = this.idElement.bind( this );
    this.inputElement = this.inputElement.bind( this );
    this.inputValue = this.inputValue.bind( this );
    this.template = this.template.bind( this );
    this.resultTemplate = this.resultTemplate.bind( this );
    this.placeholderTemplate = this.placeholderTemplate.bind( this );
    this.searchExternalTemplate = this.searchExternalTemplate.bind( this );
    this.searchExternalElement = this.searchExternalElement.bind( this );
    this.thumbnailElement = this.thumbnailElement.bind( this );
    this.autocomplete = this.autocomplete.bind( this );
    this.updateWithSelection = this.updateWithSelection.bind( this );
  }

  componentDidMount( ) {
    const renderMenuWithCategories = function ( ul, items ) {
      ul.removeClass( "ui-corner-all" ).removeClass( "ui-menu" );
      ul.addClass( "ac-menu" );
      if ( items.length === 1 && items[0].label === "loadingSuggestions" ) {
        ul.append( `<li class="category">${I18n.t( "loading_suggestions" )}</li>` );
        return;
      }
      const isVisionResults = items[0] && items[0].isVisionResult;
      let speciesCategoryShown = false;
      $.each( items, ( index, item ) => {
        if ( isVisionResults ) {
          if ( item.isCommonAncestor ) {
            const label = I18n.t( "were_pretty_sure_this_is_in_the_rank", { rank: item.rank } );
            ul.append( `<li class='category'>${label}:</li>` );
          } else if ( !speciesCategoryShown ) {
            const label = I18n.t( "here_are_our_top_species_suggestions" );
            ul.append( `<li class='category'>${label}:</li>` );
            speciesCategoryShown = true;
          }
        }
        this._renderItemData( ul, item );
      } );
    };
    const opts = Object.assign( { }, this.props, {
      extraClass: "taxon",
      idEl: this.idElement( ),
      source: this.source,
      select: this.select,
      template: this.template,
      // ensure the AC menu scrolls with the input
      appendTo: this.idElement( ).parent( ),
      minLength: 0,
      renderMenu: renderMenuWithCategories
    } );
    this.inputElement( ).genericAutocomplete( opts );
    this.fetchTaxon( );
    this.inputElement( ).bind( "assignSelection", ( e, t ) => {
      if ( !t.title ) {
        t.title = this.resultTitle( t );
      }
      this.updateWithSelection( t );
    } );
    this.inputElement( ).unbind( "resetSelection" );
    this.inputElement( ).bind( "resetSelection", ( ) => {
      if ( this.idElement( ).val( ) ) {
        this.thumbnailElement( ).css( { "background-image": "none" } );
        this.thumbnailElement( ).html(
          ReactDOMServer.renderToString( ( <Glyphicon glyph="search" /> ) )
        );
        this.idElement( ).val( null );
        if ( this.props.afterUnselect ) { this.props.afterUnselect( ); }
      }
      if ( this._mounted ) {
        this.inputElement( ).selection = null;
      }
    } );
    if ( this.props.initialSelection ) {
      this.inputElement( ).trigger( "assignSelection", this.props.initialSelection );
    }
    this._mounted = true;
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialTaxonID &&
         this.props.initialTaxonID !== prevProps.initialTaxonID ) {
      this.fetchTaxon( );
    }
    if ( !_.isEqual( this.props.visionParams, prevProps.visionParams ) ) {
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
    if ( this.props.initialTaxonID ) {
      inaturalistjs.taxa.fetch( this.props.initialTaxonID ).then( r => {
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

  updateWithSelection( item ) {
    // show the best name in the search field
    if ( item.id ) {
      this.inputElement( ).val( item.title || item.name );
    }
    // set the hidden taxon_id
    this.idElement( ).val( item.id );
    // set the selection's thumbnail image
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
        ReactDOMServer.renderToString( this.itemIcon( item ) ) );
    }
    this.inputElement( ).selection = item;
    if ( this.props.afterSelect ) { this.props.afterSelect( { item } ); }
  }

  returnVisionResults( response, callback ) {
    const visionTaxa = _.map( response.results.slice( 0, 8 ), r => {
      const taxon = new iNatModels.Taxon( r.taxon );
      taxon.isVisionResult = true;
      taxon.visionScore = r.vision_score;
      taxon.frequencyScore = r.frequency_score;
      return taxon;
    } );
    if ( response.common_ancestor ) {
      const taxon = new iNatModels.Taxon( response.common_ancestor.taxon );
      taxon.isVisionResult = true;
      taxon.isCommonAncestor = true;
      visionTaxa.unshift( taxon );
    }
    callback( visionTaxa );
  }

  visionAutocompleteSource( callback ) {
    if ( this.cachedVisionResponse ) {
      this.returnVisionResults( this.cachedVisionResponse, callback );
    } else if ( this.props.visionParams ) {
      if ( this.props.visionParams.image ) {
        inaturalistjs.computervision.score_image( this.props.visionParams ).then( r => {
          this.cachedVisionResponse = r;
          this.returnVisionResults( r, callback );
        } ).catch( e => {
          console.log( ["Error fetching vision response for photo", e] );
        } );
        callback( ["loadingSuggestions"] );
      } else if ( this.props.visionParams.observationID ) {
        const params = { id: this.props.visionParams.observationID };
        this.fetchingVision = true;
        inaturalistjs.computervision.score_observation( params ).then( r => {
          this.cachedVisionResponse = r;
          this.fetchingVision = false;
          this.returnVisionResults( r, callback );
        } ).catch( e => {
          console.log( ["Error fetching vision response for observation", e] );
        } );
        callback( ["loadingSuggestions"] );
      }
    }
  }

  taxonAutocompleteSource( request, callback ) {
    inaturalistjs.taxa.autocomplete( {
      q: request.term,
      per_page: this.props.perPage || 10,
      locale: I18n.locale,
      preferred_place_id: PREFERRED_PLACE ? PREFERRED_PLACE.id : null
    } ).then( r => {
      const results = r.results || [];
      // show as the last item an option to search external name providers
      if ( this.props.searchExternal !== false ) {
        results.push( {
          type: "search_external",
          title: I18n.t( "search_external_name_providers" )
        } );
      }
      if ( this.props.showPlaceholder &&
          !this.idElement( ).val( ) &&
          this.inputValue( ) ) {
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
        url: `/taxa/search.json?per_page=${this.props.perPage} ` +
          `&include_external=1&partial=elastic&q=${this.inputValue( )}`,
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
            if ( this.props.showPlaceholder && this.inputValue( ) ) {
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
    let name;
    if (
      this.props.config &&
      this.props.config.currentUser &&
      this.props.config.currentUser.prefers_scientific_name_first
    ) {
      name = result.name;
    } else {
      name = iNatModels.Taxon.titleCaseName( result.preferred_common_name || result.english_common_name ) || result.name;
    }
    return name;
  }

  differentMatchedTerm( result, fieldValue ) {
    if ( !result.matched_term ) { return false; }
    if ( _.includes( result.title, fieldValue ) ||
         _.includes( result.subtitle, fieldValue ) ) { return false; }
    if ( _.includes( result.title, result.matched_term ) ||
         _.includes( result.subtitle, result.matched_term ) ) { return false; }
    return ` (${_.capitalize( result.matched_term )})`;
  }

  itemPhoto( r ) {
    if ( r.default_photo ) {
      return ( <img src={ r.default_photo.square_url } /> );
    }
    return undefined;
  }

  itemIcon( r ) {
    const name = _.isFunction( r.iconicTaxonName ) ?
      r.iconicTaxonName( ).toLowerCase( ) : "unknown";
    return ( <i className={ `icon icon-iconic-${name}` } /> );
  }

  resultTemplate( r ) {
    if ( r.type === "placeholder" ) {
      return this.placeholderTemplate( r.title );
    }
    if ( r.type === "search_external" ) {
      return this.searchExternalTemplate( );
    }
    let photo = this.itemPhoto( r ) || this.itemIcon( r );
    let className = "ac";
    let extraSubtitle;
    if ( r.isVisionResult ) {
      className += " vision";
      const subtitles = [];
      if ( r.visionScore ) {
        subtitles.push( I18n.t( "visually_similar" ) );
      }
      if ( r.frequencyScore ) {
        subtitles.push( I18n.t( "seen_nearby" ) );
      }
      extraSubtitle = ( <span className="subtitle vision">{ subtitles.join( " / " ) }</span> );
    }
    return ReactDOMServer.renderToString(
      <div className={ className } data-taxon-id={ r.id }>
        <div className="ac-thumb has-photo">
          { photo }
        </div>
        <div className="ac-label">
          <span className="title">{ r.title }</span>
          <span className="subtitle">{ r.subtitle }</span>
          { extraSubtitle }
        </div>
        <a target="_blank" href={ `/taxa/${r.id}` }>
          <div className="ac-view">{ I18n.t( "view" ) }</div>
        </a>
      </div>
    );
  }

  placeholderTemplate( string ) {
    return ReactDOMServer.renderToString(
      <div className="ac ac-message" data-type="placeholder">
        <div className="ac-thumb">
          <Glyphicon glyph="search" />
        </div>
        <div className="ac-label">
          <span className="title" dangerouslySetInnerHTML={
            { __html: I18n.t( "use_name_as_a_placeholder", { name: string } ) } }
          />
          <span className="subtitle" />
          <a href="#" />
        </div>
      </div>
    );
  }

  searchExternalTemplate( ) {
    return ReactDOMServer.renderToString(
      <div className="ac ac-message" data-type="search_external">
        <div className="ac-thumb">
          <Glyphicon glyph="search" />
        </div>
        <div className="ac-label">
          <span className="title linky">
            { I18n.t( "search_external_name_providers" ) }
          </span>
          <span className="subtitle" />
          <a href="#" />
        </div>
      </div>
    );
  }

  template( r, fieldValue, options = {} ) {
    const result = _.clone( r );
    const scinameFirst = (
      this.props.config &&
      this.props.config.currentUser &&
      this.props.config.currentUser.prefers_scientific_name_first
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
        result.subtitle = iNatModels.Taxon.titleCaseName( result.preferred_common_name || result.english_common_name );
      }
      if ( !result.subtitle && result.name !== result.title ) {
        if ( result.rank_level <= 20 ) {
          result.subtitle = ( <i>{result.name}</i> );
        } else {
          result.subtitle = result.name;
        }
      }
    }
    const addition = this.differentMatchedTerm( r, fieldValue );
    if ( addition ) {
      result.title = <span>{ result.title } { addition }</span>;
    }
    if ( result.rank && ( result.rank_level > 10 || !result.subtitle ) ) {
      const rank = I18n.t( `ranks.${result.rank}`, { defaultValue: result.rank } );
      result.subtitle = <span>{ _.capitalize( rank ) } { result.subtitle }</span>;
    }
    return this.resultTemplate( result, fieldValue, options );
  }

  render( ) {
    const smallClass = this.props.small ? "input-sm" : "";
    return (
      <div className="form-group TaxonAutocomplete">
        <input type="hidden" name="taxon_id" />
        <div className={ `ac-chooser input-group ${this.props.small && "small"}` }>
          <div className={ `ac-select-thumb input-group-addon ${smallClass}` }>
            <Glyphicon glyph="search" />
          </div>
          <input
            type="text"
            name="taxon_name"
            value={ this.props.value }
            className={ `form-control ${smallClass}` }
            onChange={ this.props.onChange }
            placeholder={ this.props.placeholder || I18n.t( "species_name_cap" ) }
            autoComplete="off"
          />
          <Glyphicon className="searchclear" glyph="remove-circle"
            onClick={ () => this.inputElement( ).trigger( "resetAll" ) }
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
  resetOnChange: PropTypes.bool,
  searchExternal: PropTypes.bool,
  showPlaceholder: PropTypes.bool,
  allowPlaceholders: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  value: PropTypes.string,
  visionParams: PropTypes.object,
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  perPage: PropTypes.number,
  config: PropTypes.object
};

export default TaxonAutocomplete;
