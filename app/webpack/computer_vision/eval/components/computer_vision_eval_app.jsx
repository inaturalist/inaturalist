import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import {
  Grid, Row, Col, Button, Glyphicon
} from "react-bootstrap";
import Dropzone from "react-dropzone";
import ObsCardContainer from "../containers/obs_card_container";
import LocationChooserContainer from "../containers/location_chooser_container";
import ResultsListContainer from "../containers/results_list_container";
import TaxonomyContainer from "../containers/taxonomy_container";

class ComputerVisionEvalApp extends Component {
  constructor( props, context ) {
    super( props, context );
    this.initialDisplay = this.initialDisplay.bind( this );
    this.visionResults = this.visionResults.bind( this );
    this.otherActionButtons = this.otherActionButtons.bind( this );
    this.state = {
      observationID: null
    };
  }

  initialDisplay( ) {
    return (
      <Grid fluid>
        <div className="row-fluid">
          <Col md={12}>
            <Row>
              <div className="intro">
                <div className="start">
                  <div className="drag_or_choose">
                    <h1>Drag & drop a photo of wildlife</h1>
                    <p>{ I18n.t( "or" ) }</p>
                    <Button
                      bsStyle="primary"
                      bsSize="large"
                      onClick={( ) => {
                        this.refs.dropzone.open( );
                      }}
                    >
                      Choose photo
                      <Glyphicon glyph="upload" />
                    </Button>
                    <p>{ I18n.t( "or" ) }</p>
                    Enter observation ID:
                    <input
                      name="observation_id"
                      id="observation_id"
                      type="text"
                      onChange={e => {
                        this.setState( { observationID: e.target.value } );
                      }}
                    />
                    <Button
                      bsStyle="success"
                      bsSize="small"
                      onClick={() => {
                        this.props.lookupObservation( this.state.observationID );
                      }}
                    >
                      Go
                    </Button>
                  </div>
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
    const { apiResponse } = this.props;
    if ( _.isEmpty( apiResponse.results ) ) {
      return (
        <Row>
          <Col xs={12}>
            <div className="statement">
              Sorry, there were no results
            </div>
          </Col>
        </Row>
      );
    }

    const leaves = _.filter( apiResponse.results, t => t.right === t.left + 1 );
    const firstLeaf = _.first( _.reverse( _.sortBy( leaves, "normalized_combined_score" ) ) );
    return (
      <div>
        <div>
          <h4>What inatVisionAPI is already doing:</h4>
          <ul>
            <li>Restricting all results to the filter taxon</li>
            <li>Using location in the combined score</li>
            <li>
              Limiting results to those with a combined_score &gt; top_leaf_combined_score * 0.001
              (
              {_.round( firstLeaf.normalized_combined_score, 4 )}
              &nbsp;* 0.001 =&nbsp;
              {_.round( firstLeaf.normalized_combined_score * 0.001, 4 )}
              )
            </li>
            <li>
              Returning the top 100 remaining leaves sorted by combined_score and their ancestors
            </li>
          </ul>
        </div>
        <div className="results-views">
          <ResultsListContainer />
          <TaxonomyContainer />
        </div>
      </div>
    );
  }

  otherActionButtons( ) {
    return (
      <Row className="try-again">
        <Col xs={12}>
          <Button
            bsStyle="success"
            bsSize="large"
            onClick={( ) => {
              this.props.resetState( );
            }}
          >
            Reset
          </Button>
        </Col>
      </Row>
    );
  }

  mainContent( ) {
    const { obsCard, score, apiResponse } = this.props;
    if ( _.isEmpty( obsCard ) ) {
      return this.initialDisplay( );
    }

    let classifyButtonClass = "success";
    if ( obsCard.visionStatus ) {
      if ( obsCard.visionStatus === "failed" ) {
        classifyButtonClass = "danger";
      } else {
        classifyButtonClass = "warning";
      }
    }
    return (
      <Grid fluid className="main-content">
        <ObsCardContainer />
        <div className="classify">
          <Button
            bsStyle={classifyButtonClass}
            bsSize="large"
            disabled={!obsCard.uploadedFile || obsCard.visionStatus === "failed"}
            onClick={( ) => { score( obsCard ); }}
          >
            { obsCard.visionStatus ? (
              <div>
                <div>{ obsCard.visionStatus === "failed" ? "Oops..." : "Classifying..." }</div>
              </div>
            ) : "Classify!" }
          </Button>
          { obsCard.visionStatus === "failed" ? this.otherActionButtons( ) : "" }
        </div>
        { !_.isEmpty( apiResponse ) && (
          <Grid fluid className="results">
            { this.visionResults( ) }
            { this.otherActionButtons( ) }
          </Grid>
        ) }
      </Grid>
    );
  }

  render( ) {
    const { onFileDrop } = this.props;
    return (
      <Dropzone
        ref="dropzone"
        onDrop={( acceptedFiles, rejectedFiles, dropEvent ) => {
          // trying to protect against treating images dragged from the
          // same page from being treated as new files. Images dragged from
          // the same page will appear as multiple dataTransferItems, the
          // first being a "string" kind and not a "file" kind
          if ( dropEvent.nativeEvent.dataTransfer
            && dropEvent.nativeEvent.dataTransfer.items
            && dropEvent.nativeEvent.dataTransfer.items.length > 0
            && dropEvent.nativeEvent.dataTransfer.items[0].kind === "string" ) {
            return;
          }
          _.each( acceptedFiles, file => {
            try {
              file.preview = file.preview || window.URL.createObjectURL( file );
            } catch ( err ) {
              // eslint-disable-next-line no-console
              console.error( "Failed to generate preview for file", file, err );
            }
          } );
          onFileDrop( acceptedFiles );
        }}
        className="uploader"
        activeClassName="hover"
        disableClick
        disablePreview
        accept="image/*"
        multiple={false}
      >
        <nav className="navbar navbar-default">
          <div className="container-fluid">
            <div className="navbar-header">
              <div className="logo">
                <a href="/" className="navbar-brand" title={SITE.name} alt={SITE.name}>
                  <img alt="Site Logo" src={SITE.logo} />
                </a>
              </div>
              <div className="title">
                Computer Vision Eval
              </div>
            </div>
          </div>
        </nav>
        { this.mainContent( ) }
        <LocationChooserContainer />
      </Dropzone>
    );
  }
}

ComputerVisionEvalApp.propTypes = {
  apiResponse: PropTypes.object,
  obsCard: PropTypes.object,
  onFileDrop: PropTypes.func,
  resetState: PropTypes.func,
  lookupObservation: PropTypes.func,
  score: PropTypes.func
};

export default ComputerVisionEvalApp;
