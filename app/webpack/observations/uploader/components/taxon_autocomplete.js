import _ from "lodash";
import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import ReactDOMServer from "react-dom/server";
import inaturalistjs from "inaturalistjs";
import { Glyphicon } from "react-bootstrap";
var searchInProgress;

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
    const opts = Object.assign( { }, this.props, {
      extraClass: "taxon",
      idEl: this.idElement( ),
      source: this.source,
      select: this.select,
      template: this.template,
      // ensure the AC menu scrolls with the input
      appendTo: this.idElement( ).parent( )
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
      this.inputElement( ).selection = null;
    } );
    if ( this.props.initialSelection ) {
      this.inputElement( ).trigger( "assignSelection", this.props.initialSelection );
    }
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialTaxonID &&
         this.props.initialTaxonID !== prevProps.initialTaxonID ) {
      this.fetchTaxon( );
    }
  }

  componentWillUnmount( ) {
    this.inputElement( ).unbind( );
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

  source( request, response ) {
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
      response( _.map( results, t => new iNatModels.Taxon( t ) ) );
    } );
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
    const name = result.preferred_common_name || result.english_common_name;
    return name || result.name;
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
    return ReactDOMServer.renderToString(
      <div className="ac" data-taxon-id={ r.id }>
        <div className="ac-thumb has-photo">
          { photo }
        </div>
        <div className="ac-label">
          <span className="title">{ r.title }</span>
          <span className="subtitle">{ r.subtitle }</span>
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

  template( r, fieldValue ) {
    const result = _.clone( r );
    if ( !result.title ) {
      result.title = this.resultTitle( result );
      r.title = result.title;
    }
    if ( result.title && result.name !== result.title ) {
      if ( result.rank_level <= 10 ) {
        result.subtitle = ( <i>{result.name}</i> );
      } else {
        result.subtitle = result.name;
      }
    }
    const addition = this.differentMatchedTerm( r, fieldValue );
    if ( addition ) {
      result.title += ` ${addition}`;
    }
    if ( result.rank && ( result.rank_level > 10 || !result.subtitle ) ) {
      const rank = I18n.t( `ranks.${result.rank}`, { defaultValue: result.rank } );
      const subtitle = result.subtitle ? ` ${result.subtitle}` : "";
      result.subtitle = _.capitalize( `${rank} ${subtitle}` );
    }
    return this.resultTemplate( result, fieldValue );
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
  initialSelection: PropTypes.object,
  initialTaxonID: PropTypes.number,
  perPage: PropTypes.number
};

export default TaxonAutocomplete;
