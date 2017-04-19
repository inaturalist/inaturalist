import _ from "lodash";
import React, { PropTypes, Component } from "react";
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
  }

  about( ) {
    return (
      <div className="about">
        iNaturalist has teamed up with lorem ipsum dolor sit amet,
        consectetur adipisicing elit, sed do eiusmod tempor incididunt
        ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
        nostrud exercitation ullamco laboris nisi ut aliquip ex ea
        commodo consequat. Read more...
        <div className="logos">
          <div className="logo">
            <a href="https://sites.google.com/visipedia.org/index">
              <img src={ SITE_ICONS.visipedia } />
            </a>
          </div>
          <div className="logo">
            <a href="http://www.nvidia.com/object/machine-learning.html">
              <img src={ SITE_ICONS.nvidia } />
            </a>
          </div>
          <div className="logo">
            <a href="https://www.calacademy.org/">
              <img src={ SITE_ICONS.cas } />
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
    return (
      <Row>
        <Col xs={ 12 }>
          <div
            className="statement"
            dangerouslySetInnerHTML={ { __html: this.resultsStatement( ) } }
          />
          { _.map( _.take( this.props.obsCard.visionResults.results, 10 ), result => (
            <div className="result" key={ `result-${result.taxon.id}` }>
              <div className="title">
                <SplitTaxon taxon={ result.taxon } url={ `/taxa/${result.taxon.id}` } />
                <div className="summary">
                  Visually Similar (score: { _.round( result.vision_score, 4 ) } )
                </div>
              </div>
              <Row className="photos">
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
              </Row>
            </div>
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
    if ( ancestor ) {
      if ( ancestor.rank_level <= 10 ) {
        statement = `We're pretty sure this is
          <b>${ancestor.preferred_common_name || ancestor.name}</b>.
          Here are our top 10 results:`;
      } else {
        statement = `We're pretty sure this is in the
          ${ancestor.rank} <b>${ancestor.preferred_common_name || ancestor.name}</b>.
          Here are our top 10 results:`;
      }
    } else {
      statement =
        "We're not confident enough to make a recommendation, but here are our top 10 results:";
    }
    return statement;
  }

  refinementSuggestions( ) {
    return (
      <Row>
        <Col xs={12}>
          <div className="next-steps">
            <h3>Not happy with the results? Here's a few suggestions:</h3>
            <ul>
              <li>
                <i className="fa fa-crop" />
                Zoom in and crop the photo so little to none of the surrounding
                area is visible
              </li>
              <li>
                <i className="fa fa-calendar" />
                Specify when the photo was taken
              </li>
              <li>
                <i className="fa fa-map-marker" />
                Add a location
              </li>
              <li>
                <i className="fa fa-comments" />
                You can always submit the photo to iNaturalist.org and see what
                the community says
              </li>
            </ul>
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
        lowerSection = obsCard.visionResults ? (
          <Grid fluid className="vision-results">
            { this.visionResults( ) }
            { this.refinementSuggestions( ) }
            { this.otherActionButtons( ) }
          </Grid>
        ) : (
          <div className="classify">
            <Button bsStyle="success" bsSize="large"
              disabled={ !obsCard.uploadedFile.photo }
              onClick={ ( ) => { score( obsCard ); } }
            >
              { obsCard.visionStatus ? (
                <div>
                  <div>Classifying...</div>
                  <div className="loading_spinner" />
                </div> ) : "Classify!" }
            </Button>
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
                <a href="/" className="navbar-brand" title={ SITE.name } alt={ SITE.name }>
                  <img src={ SITE.logo } />
                </a>
                <div className="title">
                  What did you see?
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
