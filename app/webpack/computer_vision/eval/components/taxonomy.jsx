import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import {
  Grid, Row, Col, Button, Overlay, Popover
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";

/* eslint jsx-a11y/click-events-have-key-events: 0 */
/* eslint jsx-a11y/no-static-element-interactions: 0 */

class Taxonomy extends Component {
  constructor( ) {
    super( );
    this.showNodeList = this.showNodeList.bind( this );
    this.toggleTaxon = this.toggleTaxon.bind( this );
    this.setInitialOpenTaxa = this.setInitialOpenTaxa.bind( this );
    this.setOpenTaxonCombinedthreshold = this.setOpenTaxonCombinedthreshold.bind( this );
    this.toggleSettings = this.toggleSettings.bind( this );
    this.state = {
      openTaxa: [],
      showSettings: false
    };
    this.target = React.createRef( );
  }

  componentDidMount( ) {
    this.setInitialOpenTaxa( );
  }

  componentDidUpdate( prevProps ) {
    if ( !_.isEqual( _.map( prevProps.taxa, "id" ), _.map( this.props.taxa, "id" ) ) ) {
      this.setInitialOpenTaxa( );
    }
  }

  setInitialOpenTaxa( ) {
    this.setState( ( ) => ( {
      openTaxa: _.map( this.props.taxa, "parent_id" )
    } ) );
  }

  setOpenTaxonCombinedthreshold( threshold ) {
    this.props.updateUserSetting( "openTaxonCombinedThreshold", threshold );
  }

  settingsButton( ) {
    const popover = (
      <div className="settings">
        <div>
          Min Combined Score Threshold:
          <input
            type="text"
            name="threshold"
            value={this.props.toggleableSettings.openTaxonCombinedThreshold}
            onChange={e => this.setOpenTaxonCombinedthreshold( e.target.value )}
          />
        </div>
      </div>
    );

    return (
      <span className="settingsButtonWrapper">
        <Button
          bsRole="toggle"
          bsStyle="default"
          className="settingsButton"
          ref={this.target}
          onClick={this.toggleSettings}
        >
          <i className="fa fa-sliders" />
          Settings
        </Button>
        <Overlay
          show={this.state.showSettings}
          onHide={( ) => this.setState( { showSettings: false } )}
          container={$( "#app" ).get( 0 )}
          placement="bottom"
          target={( ) => ReactDOM.findDOMNode( this.target.current )}
          rootClose
        >
          <Popover
            id="SettingsPopover"
            placement="bottom"
            positionLeft={0}
          >
            {popover}
          </Popover>
        </Overlay>
      </span>
    );
  }

  toggleSettings( ) {
    const { showSettings } = this.state;
    this.setState( { showSettings: !showSettings } );
  }

  toggleTaxon( taxon, options = { } ) {
    if ( !taxon ) {
      return;
    }

    if ( options.expand ) {
      this.setState( prevState => ( {
        openTaxa: _.uniq( prevState.openTaxa.concat(
          _.map(
            _.filter(
              this.props.taxa,
              t => t.left >= taxon.left && t.right <= taxon.right
            ),
            "taxon_id"
          )
        ) )
      } ) );
      return;
    }

    if ( options.collapse ) {
      this.setState( prevState => ( {
        openTaxa: _.without(
          prevState.openTaxa,
          ..._.map(
            _.filter(
              this.props.taxa,
              t => t.left >= taxon.left && t.right <= taxon.right
            ),
            "taxon_id"
          )
        )
      } ) );
      return;
    }

    if ( _.includes( this.state.openTaxa, taxon.taxon_id ) ) {
      this.setState( prevState => ( {
        openTaxa: _.without( prevState.openTaxa, taxon.taxon_id )
      } ) );
      return;
    }

    this.setState( prevState => ( {
      openTaxa: prevState.openTaxa.concat( [taxon.taxon_id] )
    } ) );
  }

  showNodeList( result ) {
    const {
      taxa, config, setHoverResult, hoverResult
    } = this.props;
    const taxonID = result ? result.taxon_id : null;
    const isOpen = result ? _.includes( this.state.openTaxa, result.taxon_id ) : true;
    const childrenTaxa = _.filter( taxa, t => (
      t.parent_id === taxonID
    ) );
    const isRoot = !result;
    const isLeaf = _.isEmpty( childrenTaxa );
    const isInFocus = hoverResult && result
      && ( ( result.taxon_id === hoverResult.taxon_id )
        || ( result.left >= hoverResult.left
          && result.right <= hoverResult.right
          && result.right === result.left + 1 ) );
    return (
      <li
        className="branch"
        taxon-id={`branch-${taxonID}`}
        key={`branch-${taxonID}`}
      >
        <div
          className={`name-row${isInFocus ? " focus" : ""}`}
          onMouseOver={() => setHoverResult( result )}
        >
          <div
            className={`name${isLeaf ? " leaf" : " nonleaf"}`}
            onClick={( ) => this.toggleTaxon( result )}
          >
            { isRoot ? (
              <div className="name-label featured-ancestor display-name">
                { I18n.t( "all_taxa.life" ) }
              </div>
            ) : (
              <SplitTaxon
                taxon={_.isEmpty( result.taxon ) ? result : result.taxon}
                user={config.currentUser}
                noInactive
              />
            ) }
            { isRoot || (
              <a
                target="_blank"
                href={`/taxa/${result.taxon_id}`}
                rel="noopener noreferrer"
                onClick={e => {
                  e.stopPropagation( );
                }}
              >
                <i className="fa fa-file-text-o" />
              </a>
            ) }
            { ( isLeaf || isRoot ) ? null : (
              <span
                className={`icon-collapse ${isOpen ? "" : "disabled"}`}
                onClick={e => {
                  e.stopPropagation( );
                  this.toggleTaxon( result, { collapse: true } );
                }}
                title={I18n.t( "views.lifelists.collapse_this_branch" )}
              />
            ) }
            { ( !isRoot && !isLeaf ) ? (
              <span
                className="icon-expand"
                onClick={e => {
                  e.stopPropagation( );
                  this.toggleTaxon( result, { expand: true } );
                }}
                title={I18n.t( "views.lifelists.expand_all_nodes_in_this_branch" )}
              />
            ) : null }
          </div>
          <div className="scores">
            <div className="score">
              { isRoot ? "Vision" : _.round( result.vision_score, 3 ) }
            </div>
            <div className="score">
              { isRoot ? "Combined" : _.round( result.normalized_combined_score, 3 ) }
            </div>
            <div className="score">
              { isRoot ? "Geo" : _.round( result.raster_geo_score, 3 ) }
            </div>
            <div className="score">
              { isRoot ? "H3Geo" : _.round( result.geo_score, 3 ) }
            </div>
            <div className="score">
              { isRoot ? "Threshold" : _.round( result.geo_threshold, 3 ) }
            </div>
          </div>
        </div>
        { isOpen && !isLeaf ? (
          <ul className="nested">
            { _.map( _.reverse( _.sortBy( childrenTaxa, "normalized_combined_score" ) ), this.showNodeList ) }
          </ul>
        ) : null }
      </li>
    );
  }

  render( ) {
    return (
      <div id="Taxonomy">
        { this.settingsButton( ) }
        <ul className="tree">
          { this.showNodeList( ) }
        </ul>
      </div>
    );
  }
}

Taxonomy.propTypes = {
  taxa: PropTypes.array,
  config: PropTypes.object,
  setHoverResult: PropTypes.func,
  hoverResult: PropTypes.object,
  updateUserSetting: PropTypes.func,
  toggleableSettings: PropTypes.object
};

export default Taxonomy;
