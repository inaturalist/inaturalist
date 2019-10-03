import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col, Button, Glyphicon } from "react-bootstrap";
import Dropzone from "react-dropzone";
import ObsCardComponent from "./obs_card_component";
import SplitTaxon from "../../shared/components/split_taxon";
import LocationChooser from "../../observations/uploader/components/location_chooser";
/* global SITE_ICONS */

class ComputerVisionDemoApp extends Component {

  constructor( props, context ) {
    super( props, context );
    this.initialDisplay = this.initialDisplay.bind( this );
    this.visionResults = this.visionResults.bind( this );
    this.resultsStatement = this.resultsStatement.bind( this );
    this.otherActionButtons = this.otherActionButtons.bind( this );
    this.resizeElement = this.resizeElement.bind( this );
  }

  componentDidMount( ) {
    this.resizeElement( $( ".uploader" ) );
  }

  resizeElement( el ) {
    if ( el.length === 0 ) { return; }
    const topOffset = el.offset( ).top;
    const height = $( window ).height( );
    const difference = height - topOffset;
    if ( difference > 450 ) {
      el.css( "min-height", difference );
    }
  }

  about( ) {
    return (
      <div className="about">
        <a href="https://www.inaturalist.org">iNaturalist</a> has teamed up with
        the <a href="https://sites.google.com/visipedia.org/index">
        Visipedia</a> project and <a href="http://www.nvidia.com/object/machine-learning.html">
        NVIDIA</a> to begin exploring how computer vision can help speed up the identification
        process on iNaturalist. This demo uses a work-in-progress model that we've
        trained on iNaturalist images. Drag in an image to see how the model performs.
        We're currently working on improving this model and integrating it into
        the iNaturalist web and mobile
        apps. <a href="https://www.inaturalist.org/pages/computer_vision_demo">Read more...</a>
        <div className="logos">
          <div className="logo">
            <a href="https://sites.google.com/visipedia.org/index">
              <img src={ SITE_ICONS.visipedia } />
            </a>
          </div>
          <div className="logo">
            <a href="https://www.calacademy.org/">
              <img src={ SITE_ICONS.cas } />
            </a>
          </div>
          <div className="logo">
            <a href="http://www.nvidia.com/object/machine-learning.html">
              <img src={ SITE_ICONS.nvidia } />
            </a>
          </div>
        </div>
      </div>
    );
  }

  initialDisplay( ) {
    return (
      <Grid fluid>
        <div className="row-fluid">
          <Col md={ 12 }>
            <Row>
              <div className="intro">
                <div className="start">
                  <div className="drag_or_choose">
                    <h1>Drag & drop a photo of wildlife</h1>
                    <p>{ I18n.t( "or" ) }</p>
                    <Button bsStyle="primary" bsSize="large"
                      onClick={ ( ) => {
                        this.refs.dropzone.open( );
                      } }
                    >
                      Choose photo
                      <Glyphicon glyph="upload" />
                    </Button>
                  </div>
                  { this.about( ) }
                </div>
                <div className="hover">
                  <p>{ I18n.t( "drop_it" ) }</p>
                </div>
              </div>
            </Row>
          </Col>
        </div>
      </Grid>
    );
  }

  visionResults( ) {
    const obsCard = this.props.obsCard;
    if ( _.isEmpty( obsCard.visionResults.results ) ) {
      return (
        <Row>
          <Col xs={ 12 }>
            <div className="statement">
              Sorry, there were no results within {
                obsCard.selected_taxon.preferred_common_name || obsCard.selected_taxon.name }
            </div>
          </Col>
        </Row>
      );
    }
    return (
      <Row>
        <Col xs={ 12 }>
          <div
            className="statement"
            dangerouslySetInnerHTML={ { __html: this.resultsStatement( ) } }
          />
          { _.map( _.take( obsCard.visionResults.results, 10 ), result => (
            <Col xs={ 12 } className="result" key={ `result-${result.taxon.id}` }>
              <Row className="title">
                <SplitTaxon taxon={ result.taxon } url={ `/taxa/${result.taxon.id}` } />
                <div className="summary">
                  { result.vision_score ? "Visually Similar" : "" }
                  { result.vision_score && result.frequency_score ? " / " : "" }
                  { result.frequency_score ? "Seen Nearby" : "" }
                </div>
              </Row>
              <Row>
                <div className="photos">
                  { _.map( _.take( result.taxon.taxon_photos, 6 ), tp => (
                    <Col xs={ 2 } key={ `photo-${tp.photo.id}` }>
                      <a
                        className="photo"
                        href={ `/taxa/${tp.taxon.id}` }
                        title={ tp.taxon.preferred_common_name || tp.taxon.name }
                        style={ {
                          backgroundImage: `url( '${tp.photo.small_url}')`
                        } }
                      />
                    </Col>
                  ) ) }
                </div>
              </Row>
            </Col>
          ) ) }
        </Col>
      </Row>
    );
  }

  resultsStatement( ) {
    let statement;
    const ancestor = this.props.obsCard.visionResults &&
                     this.props.obsCard.visionResults.common_ancestor &&
                     this.props.obsCard.visionResults.common_ancestor.taxon;
    const count = _.size( this.props.obsCard.visionResults.results );
    if ( ancestor ) {
      if ( ancestor.rank_level <= 10 ) {
        statement = `We're pretty sure this is
          <b>${ancestor.preferred_common_name || ancestor.name}</b>.
          Here are our top ${count} results:`;
      } else {
        statement = `We're pretty sure this is in the <a href="/taxa/${ancestor.id}">
          ${ancestor.rank} <b>${ancestor.preferred_common_name || ancestor.name}</b></a>.
          Here are our top ${count} results:`;
      }
    } else {
      statement = `We're not confident enough to make a recommendation,
        but here are our top ${count} results:`;
    }
    return statement;
  }

  refinementSuggestions( ) {
    return (
      <Row>
        <Col xs={12}>
          <div className="next-steps">
            <h3>Not happy with the results? Here's a few suggestions:</h3>
            <div className="suggestions">
              <div className="suggestion">
                <div className="icon"><i className="fa fa-crop" /></div>
                <div className="text">
                  Zoom in and crop the photo so little to none of the surrounding
                  area is visible
                </div>
              </div>
              <div className="suggestion">
                <div className="icon"><i className="fa fa-calendar" /></div>
                <div className="text">Specify when the photo was taken</div>
              </div>
              <div className="suggestion">
                <div className="icon"><i className="fa fa-map-marker" /></div>
                <div className="text">Add a location</div>
              </div>
              <div className="suggestion">
                <div className="icon"><i className="fa fa-comments" /></div>
                <div className="text">
                  You can always submit the photo
                  to <a href="https://www.inaturalist.org">iNaturalist</a> and
                  see what the community says
                </div>
              </div>
            </div>
          </div>
        </Col>
      </Row>
    );
  }

  otherActionButtons( ) {
    return (
      <Row className="try-again">
        <Col xs={12}>
          <Button bsStyle="success" bsSize="large" onClick={ ( ) => {
            this.props.resetState( );
          } }
          >
            Try Another Photo
          </Button>
          <Button bsStyle="default" bsSize="large" href="https://www.inaturalist.org">
            Check Out iNaturalist
          </Button>
        </Col>
      </Row>
    );
  }

  render( ) {
    const { obsCard, onFileDrop, score } = this.props;
    let content;
    if ( _.isEmpty( obsCard.uploadedFile ) ) {
      content = this.initialDisplay( );
    } else {
      let lowerSection;
      if ( obsCard.uploadedFile ) {
        let loadingSpinner = obsCard.visionStatus === "loading" ?
          ( <div className="loading_spinner" /> ) : "";
        lowerSection = obsCard.visionResults ? (
          <Grid fluid className="vision-results">
            { this.visionResults( ) }
            { _.isEmpty( obsCard.visionResults.results ) ? "" : this.refinementSuggestions( ) }
            { this.otherActionButtons( ) }
          </Grid>
        ) : (
          <div className="classify">
            <Button bsStyle="success" bsSize="large"
              disabled={ !obsCard.uploadedFile.photo || obsCard.visionStatus === "failed" }
              onClick={ ( ) => { score( obsCard ); } }
            >
              { obsCard.visionStatus ? (
                <div>
                  <div>{ obsCard.visionStatus === "failed" ? "Oops..." : "Classifying..." }</div>
                  { loadingSpinner }
                </div> ) : "Classify!" }
            </Button>
            { obsCard.visionStatus === "failed" ? this.otherActionButtons( ) : "" }
          </div>
        );
      }
      content = (
        <Grid fluid>
          <div className="row-fluid results">
            <ObsCardComponent
              { ...this.props }
            />
            { lowerSection }
          </div>
          { this.about( ) }
        </Grid>
      );
    }
    /* global SITE */
    return (
      <div>
        <Dropzone
          ref="dropzone"
          onDrop={ onFileDrop }
          className="uploader"
          activeClassName="hover"
          disableClick
          accept="image/*"
          multiple={ false }
        >
          <nav className="navbar navbar-default">
            <div className="container-fluid">
              <div className="navbar-header">
                <div className="logo">
                  <a href="/" className="navbar-brand" title={ SITE.name } alt={ SITE.name }>
                    <img src={ SITE.logo } />
                  </a>
                </div>
                <div className="title">
                  Computer Vision Demo
                </div>
              </div>
            </div>
          </nav>
          { content }
        </Dropzone>
        <LocationChooser
          updateSingleObsCard
          { ...this.props }
          { ...this.props.locationChooser }
          submitText={ I18n.t( "select" ) }
        />
      </div>
    );
  }
}

ComputerVisionDemoApp.propTypes = {
  obsCard: PropTypes.object,
  locationChooser: PropTypes.object,
  onFileDrop: PropTypes.func,
  resetState: PropTypes.func,
  score: PropTypes.func,
  updateState: PropTypes.func
};

export default ComputerVisionDemoApp;
