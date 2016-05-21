import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Button, Popover, Overlay, Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import { DEFAULT_PARAMS } from "../reducers/search_params_reducer";
import PlaceAutocomplete from "./place_autocomplete";
import ProjectAutocomplete from "./project_autocomplete";
import UserAutocomplete from "./user_autocomplete";
import DateFilters from "./date_filters";

class FiltersButton extends React.Component {
  constructor( props ) {
    super( props );
    const params = props.params;
    const diffs = _.difference( _.values( params ), _.values( DEFAULT_PARAMS ) );
    this.state = {
      moreFiltersHidden: diffs.length === 0,
      show: false
    };
    this.clickOffEventNamespace = "click.FiltersButtonClickOff";
  }

  toggle( ) {
    if ( this.state.show ) {
      this.hide( );
      return;
    }
    this.show( );
  }

  show( ) {
    this.setState( { show: true } );
    const that = this;
    $( "body" ).on( this.clickOffEventNamespace, e => {
      if ( !$( ".FiltersButtonWrapper" ).is( e.target ) &&
          $( ".FiltersButtonWrapper" ).has( e.target ).length === 0 &&
          $( ".in" ).has( e.target ).length === 0 &&
          $( e.target ).parents( ".ui-autocomplete " ).length === 0 &&
          $( e.target ).parents( ".ui-datepicker " ).length === 0 &&
          $( e.target ).parents( ".ui-datepicker-header " ).length === 0 &&
          $( e.target ).parents( ".ui-multiselect-menu " ).length === 0 &&
          $( e.target ).parents( ".observation-field " ).length === 0
        ) {
        that.hide( );
      }
    } );
  }

  hide( ) {
    this.setState( { show: false } );
    $( "body" ).unbind( this.clickOffEventNamespace );
  }

  render( ) {
    const { params, updateSearchParams } = this.props;
    const paramsForUrl = ( ) => window.location.search.replace( /^\?/, "" );
    const closeFilters = ( ) => {
      // yes it's a horrible hack
      $( ".FiltersButton" ).click( );
    };
    const resetParams = ( ) => updateSearchParams( DEFAULT_PARAMS );
    const numFiltersSet = ( ) => {
      const diffs = _.difference( _.values( params ), _.values( DEFAULT_PARAMS ) );
      return diffs.length > 0 ? diffs.length.toString() : "";
    };
    const filterCheckbox = ( checkbox ) => {
      const checkedVal = ( checkbox.checked || true );
      return (
        <div
          className={
            `checkbox ${params[checkbox.param] && params[checkbox.param] === checkedVal ? "filter-changed" : ""}`
          }
          key={`filters-${checkbox.param}-${checkbox.label}`}
        >
          <label>
            <input
              type="checkbox"
              defaultChecked={ params[checkbox.param] === checkedVal }
              onChange={ ( e ) => {
                let newVal = checkbox.unchecked;
                if ( e.target.checked ) newVal = checkedVal;
                updateSearchParams( {
                  [checkbox.param]: newVal
                } );
              }}
            /> { _.capitalize( I18n.t( checkbox.label || checkbox.param ) ) }
          </label>
        </div>
      );
    };
    const visibleRanks = [
      "kingdom",
      "phylum",
      "subphylum",
      "superclass",
      "class",
      "subclass",
      "superorder",
      "order",
      "suborder",
      "infraorder",
      "superfamily",
      "epifamily",
      "family",
      "subfamily",
      "supertribe",
      "tribe",
      "subtribe",
      "genus",
      "genushybrid",
      "species",
      "hybrid",
      "subspecies",
      "variety",
      "form"
    ];
    const orderByFields = [
      { value: "observations.id", default: "date added", key: "date_added" },
      { value: "observed_on", default: "date observed", key: "date_observed" },
      { value: "votes", default: "faves", key: "faves" }
    ];
    const canShowObservationFields = ( ) => (
      params.observationFields && _.size( params.observationFields ) > 0
    );
    const iconicTaxonButton = ( t, i ) => {
      let cssClass = "iconic-taxon";
      if ( ( i + 1 ) % 6 === 0 ) {
        cssClass += " last";
      }
      if ( _.includes( params.iconic_taxa, t.name ) ) {
        cssClass += " filter-changed active";
      }
      return (
        <Button
          className={cssClass}
          title={ _.capitalize( I18n.t( t.label ) ) }
          key={`btn-${t.name}`}
          onClick={ ( ) => {
            let newIconicTaxa;
            if ( _.includes( params.iconic_taxa, t.name ) ) {
              newIconicTaxa = _.without( params.iconic_taxa, t.name );
            } else {
              newIconicTaxa = params.iconic_taxa.map( n => n );
              newIconicTaxa.push( t.name );
            }
            updateSearchParams( {
              iconic_taxa: newIconicTaxa
            } );
          } }
        >
          <i className={`icon-iconic-${t.name.toLowerCase( )}`} />
        </Button>
      );
    };
    const licenses = [
      "CC0",
      "CC-BY",
      "CC-BY-NC",
      "CC-BY-SA",
      "CC-BY-ND",
      "CC-BY-NC-SA",
      "CC-BY-NC-ND"
    ];
    const mainLeftCol = (
      <Col xs="4">
        <Row>
          <Col xs="12">
            <label className="sectionlabel">
              { _.capitalize( I18n.t( "show" ) ) }
            </label>
          </Col>
        </Row>
        <Row id="show-filters">
          <Col id="filters-left-col" xs="6">
            { [
              { param: "wild" },
              { param: "verifiable", label: "verifiable", unchecked: "any" },
              { param: "quality_grade", label: "research_grade", checked: "research", unchecked: "any" },
              { param: "quality_grade", label: "needs_id", checked: "needs_id", unchecked: "any" },
              { param: "threatened" }
            ].map( filterCheckbox ) }
          </Col>
          <Col id="filters-left-col" xs="6">
            { [
              { param: "introduced" },
              { param: "popular" },
              { param: "sounds", label: "has_sounds" },
              { param: "photos", label: "has_photos" },
              { param: "user_id", label: "your_observations", checked: CURRENT_USER.id }
            ].map( filterCheckbox ) }
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <div className="form-group">
              <label className="sectionlabel" htmlFor="params-q">
                { I18n.t( "description_slash_tags" ) }
              </label>
              <input
                id="params-q"
                className="form-control"
                placeholder={ I18n.t( "blue_butterfly_etc" ) }
                value={ params.q }
                onChange={ ( e ) => {
                  updateSearchParams( { q: e.target.value } );
                } }
              />
            </div>
          </Col>
        </Row>
      </Col>
    );
    const mainCenterCol = (
      <Col xs="4" id="filters-center-col">
        <Row>
          <Col xs="12">
            <label className="sectionlabel">
              { _.capitalize( I18n.t( "categories" ) ) }
            </label>
            <div id="filters-categories" className="btn-group">
              { [
                { name: "Aves", label: "birds" },
                { name: "Amphibia", label: "amphibians" },
                { name: "Reptilia", label: "reptiles" },
                { name: "Mammalia", label: "mammals" },
                { name: "Actinopterygii", label: "ray_finned_fishes" },
                { name: "Mollusca", label: "mollusks" }
              ].map( iconicTaxonButton ) }
              { [
                { name: "Arachnida", label: "arachnids" },
                { name: "Insecta", label: "insects" },
                { name: "Plantae", label: "plants" },
                { name: "Fungi", label: "fungi" },
                { name: "Protozoa", label: "protozoans" },
                { name: "unknown", label: "unknown" }
              ].map( iconicTaxonButton ) }
            </div>
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel" htmlFor="params-hrank">
              { _.capitalize( I18n.t( "rank" ) ) }
            </label>
          </Col>
        </Row>
        <Row id="filters-ranks">
          <Col xs="6">
            <select
              id="params-hrank"
              className={`form-control ${params.hrank ? "filter-changed" : ""}`}
              defaultValue={params.hrank}
              onChange={ e => updateSearchParams( { hrank: e.target.value } ) }
            >
              <option value="">
                { _.capitalize( I18n.t( "high" ) ) }
              </option>
              { visibleRanks.map( rank => (
                <option key={`params-hrank-${rank}`} value={rank}>
                  { _.capitalize( I18n.t( `ranks.${rank}` ) ) }
                </option>
              ) ) }
            </select>
          </Col>
          <Col xs="6">
            <select
              id="params-lrank"
              className={`form-control ${params.lrank ? "filter-changed" : ""}`}
              defaultValue={params.lrank}
              onChange={ e => updateSearchParams( { lrank: e.target.value } ) }
            >
              <option value="">
                { _.capitalize( I18n.t( "low" ) ) }
              </option>
              { visibleRanks.map( rank => (
                <option key={`params-lrank-${rank}`} value={rank}>
                  { _.capitalize( I18n.t( `ranks.${rank}` ) ) }
                </option>
              ) ) }
            </select>
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel" htmlFor="params-order-by">
              { _.capitalize( I18n.t( "sort_by" ) ) }
            </label>
          </Col>
        </Row>
        <Row>
          <Col xs="6">
            <select
              id="params-order-by"
              className={
                "form-control" +
                ` ${params.order_by !== DEFAULT_PARAMS.order_by ? "filter-changed" : ""}`
              }
              onChange={ e => updateSearchParams( { order_by: e.target.value } ) }
            >
              { orderByFields.map( field => (
                <option value={field.value} key={`params-order-by-${field.value}`}>
                  { _.capitalize( I18n.t( field.key, { defaultValue: field.default } ) ) }
                </option>
              ) ) }
            </select>
          </Col>
          <Col xs="6">
            <select
              id="params-order"
              defaultValue="desc"
              className={
                "form-control" +
                ` ${params.order !== DEFAULT_PARAMS.order ? "filter-changed" : ""}`
              }
              onChange={ e => updateSearchParams( { order: e.target.value } ) }
            >
              <option value="asc">
                { I18n.t( "asc" ) }
              </option>
              <option value="desc">
                { I18n.t( "desc" ) }
              </option>
            </select>
          </Col>
        </Row>
      </Col>
    );
    const mainRightCol = (
      <Col xs="4" id="filters-right-col">
        <label className="sectionlabel">
          { _.capitalize( I18n.t( "date_observed" ) ) }
        </label>
        <DateFilters params={params} updateSearchParams={updateSearchParams} />
        <div
          id="filters-observation-fields"
          className={ canShowObservationFields( ) ? "" : "collapse" }
        >
          <label className="sectionlabel">
            { I18n.t( "observation_fields" ) }
          </label>
          { _.forEach( params.observationFields, ( v, k ) => (
            <span className="observation-field" key={`observation-field-${k}`}>
              { k }={ v }
              <button
                onClick={ ( ) => {
                  updateSearchParams( {
                    observationFields: _.omit( params.observationFields, [k] )
                  } );
                } }
              >
                &times;
              </button>
            </span>
          ) ) }
          <input type="hidden" name="taxon_ids[]" />
          <input type="hidden" name="taxon_ids" />
          <input type="hidden" name="has[]" />
          <input type="hidden" name="not_in_project" />
          <input type="hidden" name="lat" />
          <input type="hidden" name="lng" />
          <input type="hidden" name="viewer_id" />
          <input type="hidden" name="identified" />
          <input type="hidden" name="captive" />
          <input type="hidden" name="day" />
          <input type="hidden" name="year" />
          <input type="hidden" name="site_id" />
          <input type="hidden" name="projects[]" />
          <input type="hidden" name="apply_project_rules_for" />
          <input type="hidden" name="not_matching_project_rules_for" />
          <input type="hidden" name="list_id" />
          <input type="hidden" name="changed_fields" />
          <input type="hidden" name="changed_since" />
          <input type="hidden" name="change_project_id" />
        </div>
      </Col>
    );
    const mainFilters = (
      <Row>
        { mainLeftCol }
        { mainCenterCol}
        { mainRightCol }
      </Row>
    );
    const moreLeftCol = (
      <Col xs="4">
        <div className="form-group">
          <label className="sectionlabel" htmlFor="params-user-id">
            { _.capitalize( I18n.t( "person" ) ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon icon-person"></span>
            <UserAutocomplete
              resetOnChange={false}
              initialUserID={params.user_id}
              bootstrapClear
              className={params.user_id ? "filter-changed" : ""}
              afterSelect={ function ( result ) {
                updateSearchParams( { user_id: result.item.id } );
              } }
              afterUnselect={ function ( ) {
                updateSearchParams( { user_id: null } );
              } }
            />
            <input value={ params.user_id } type="hidden" name="user_id" />
          </div>
        </div>
        <div className="form-group">
          <label className="sectionlabel" htmlFor="params-project-id">
            { _.capitalize( I18n.t( "project" ) ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon fa fa-briefcase"></span>
            <ProjectAutocomplete
              resetOnChange={false}
              initialProjectID={params.project_id}
              bootstrapClear
              className={params.project_id ? "filter-changed" : ""}
              afterSelect={ function ( result ) {
                updateSearchParams( { project_id: result.item.id } );
              } }
              afterUnselect={ function ( ) {
                updateSearchParams( { project_id: null } );
              } }
            />
            <input value={ params.project_id } type="hidden" name="project_id" />
          </div>
        </div>
        <div className="form-group">
          <label className="sectionlabel" htmlForm="params-place-name">
            { _.capitalize( I18n.t( "place" ) ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon fa fa-globe"></span>
            <PlaceAutocomplete
              resetOnChange={false}
              initialPlaceID={params.place_id}
              bootstrapClear
              className={params.place_id ? "filter-changed" : ""}
              afterSelect={ function ( result ) {
                updateSearchParams( { place_id: result.item.id } );
              } }
              afterUnselect={ function ( ) {
                updateSearchParams( { place_id: null } );
              } }
            />
            <input type="hidden" name="place_id" />
          </div>
        </div>
      </Col>
    );
    const moreCenterCol = (
      <Col xs="4">
        <div className="form-group">
          <label className="sectionlabel">
            { _.capitalize( I18n.t( "photo_licensing" ) ) }
          </label>
          <select
            className={`form-control ${params.photo_license ? "filter-changed" : ""}`}
            value={ params.photo_license }
            onChange={ e => updateSearchParams( { photo_license: e.target.value } ) }
          >
            <option value="">{ I18n.t( "all" ) }</option>
            {licenses.map( ( code ) => (
              <option key={`photo-licenses-${code}`} value={ code }>{ code }</option>
            ) ) }
          </select>
        </div>
        <label className="sectionlabel">
          { I18n.t( "reviewed" ) }
        </label>
        <div className={`form-group ${params.reviewed ? "filter-changed" : ""}`}>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed"
              defaultChecked={params.reviewed === undefined || params.reviewed === null}
              onClick={ ( ) => updateSearchParams( { reviewed: "any" } ) }
            />
            { I18n.t( "any" ).toLowerCase( ) }
          </label>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed"
              value="true"
              defaultChecked={params.reviewed === true}
              onClick={ ( ) => updateSearchParams( { reviewed: true } ) }
            />
            { I18n.t( "yes" ).toLowerCase( ) }
          </label>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed"
              value="false"
              defaultChecked={params.reviewed === false}
              onClick={ ( ) => updateSearchParams( { reviewed: false } ) }
            />
            { I18n.t( "no" ).toLowerCase( ) }
          </label>
        </div>
      </Col>
    );
    const moreRightCol = (
      <Col xs="4">
        <label className="sectionlabel">
          { _.capitalize( I18n.t( "date_added" ) ) }
        </label>
        <DateFilters params={params} updateSearchParams={updateSearchParams} prefix="created" />
      </Col>
    );
    const moreFilters = (
      <div id="more-filters" className={this.state.moreFiltersHidden ? "hidden" : ""}>
        <Row>
          { moreLeftCol }
          { moreCenterCol }
          { moreRightCol }
        </Row>
      </div>
    );
    const popover = (
      <Grid className="FiltersButtonContainer">
        <div id="filters-body">
          { mainFilters }
          <Row>
            <Col xs="12">
              <Button
                id="filters-more-btn"
                bsStyle="link"
                className={this.state.moreFiltersHidden ? "collapsed" : ""}
                onClick={ ( ) => {
                  this.setState( { moreFiltersHidden: !this.state.moreFiltersHidden } );
                }}
              >
                { _.capitalize( I18n.t( "more_filters" ) ) }
                &nbsp;
                <i className="fa fa-caret-down"></i>
                <i className="fa fa-caret-up"></i>
              </Button>
              { moreFilters }
            </Col>
          </Row>
        </div>
        <Row id="filters-footer" className="FiltersButtonFooter">
          <Col xs="12">
            <Button bsStyle="primary" onClick={ () => closeFilters( ) }>
              { _.capitalize( I18n.t( "update_search" ) ) }
            </Button>
            <Button onClick={ ( ) => resetParams( ) }>
              { _.capitalize( I18n.t( "reset_search_filters" ) ) }
            </Button>
            <div id="feeds" className="feeds pull-right">
              <a
                className="btn btn-link" href={`/observations.atom?${paramsForUrl( )}`}
                target="_self"
              >
                <i className="fa fa-rss"></i>
                <span>{ I18n.t( "atom" ) }</span>
              </a>
              <a
                className="btn btn-link" href={`/observations.kml?${paramsForUrl( )}`}
                target="_self"
              >
                <i className="fa fa-globe"></i>
                <span>{ I18n.t( "kml" ) }</span>
              </a>
              <a
                className="btn btn-link" href={`/observations/export?${paramsForUrl( )}`}
                target="_self"
              >
                <i className="fa fa-download"></i>
                <span>{ I18n.t( "download" ) }</span>
              </a>
            </div>
          </Col>
        </Row>
      </Grid>
    );
    return (
      <span className="FiltersButtonWrapper">
        <Button
          bsRole="toggle"
          bsStyle="default"
          className="FiltersButton"
          ref="target"
          onClick={ ( ) => this.toggle( ) }
        >
          <i className="fa fa-sliders"></i> { I18n.t( "filters" ) }
          &nbsp;
          <span className="badge">
            { numFiltersSet( ) }
          </span>
        </Button>
        <Overlay
          show={this.state.show}
          onHide={ ( ) => this.setState( { show: false } ) }
          container={ $( "#wrapper.bootstrap" ).get( 0 ) }
          placement="bottom"
          target={ ( ) => ReactDOM.findDOMNode( this.refs.target ) }
        >
          <Popover
            id="FiltersButtonPopover"
            className="FiltersButtonPopover"
            placement="bottom"
          >
            {popover}
          </Popover>
        </Overlay>
      </span>
    );
  }
}

FiltersButton.propTypes = {
  params: PropTypes.object,
  updateSearchParams: PropTypes.func
};

export default FiltersButton;
