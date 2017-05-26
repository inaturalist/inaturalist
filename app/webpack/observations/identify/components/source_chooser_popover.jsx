import React, { PropTypes } from "react";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import _ from "lodash";

class SourceChooserPopover extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      sources: ["observations", "checklist"],
      current: 0
    };
  }

  componentWillReceiveProps( newProps ) {
    this.setState( { current: this.state.sources.indexOf( newProps.source ) } );
  }

  chooseCurrent( ) {
    const currentSource = this.state.sources[this.state.current];
    // Dumb, but I don't see a better way to explicity close the popover
    $( "body" ).click( );
    if ( currentSource ) {
      this.props.setSource( currentSource );
    } else {
      this.props.clearSource( );
    }
  }

  render( ) {
    const {
      container,
      source,
      className,
      preIconClass,
      postIconClass
    } = this.props;
    return (
      <OverlayTrigger
        trigger="click"
        placement="bottom"
        rootClose
        container={container}
        overlay={
          <Popover className="SourceChooserPopover RecordChooserPopover">
            <ul className="list-unstyled">
              <li
                className={this.state.current === -1 ? "current" : ""}
                onMouseOver={( ) => {
                  this.setState( { current: -1 } );
                }}
                onClick={( ) => this.chooseCurrent( )}
                className="pinned"
                style={{ display: this.props.source ? "block" : "none" }}
              >
                <i className="fa fa-times"></i>
                { _.capitalize( I18n.t( "clear" ) ) }
              </li>
              { _.map( this.state.sources, ( s, i ) => (
                <li
                  key={`source-chooser-source-${s}`}
                  className={ `media ${this.state.current === i ? "current" : ""}` }
                  onClick={( ) => this.chooseCurrent( )}
                  onMouseOver={( ) => {
                    this.setState( { current: i } );
                  }}
                >
                  <div className="media-left">
                    <i className="media-object fa fa-map-marker"></i>
                  </div>
                  <div className="media-body">
                    { I18n.t( s ) }
                  </div>
                </li>
              ) ) }
            </ul>
          </Popover>
        }
      >
        <div
          className={`SourceChooserPopoverTrigger RecordChooserPopoverTrigger ${source ? "chosen" : ""} ${className}`}
        >
          { preIconClass ? <i className={`${preIconClass} pre-icon`}></i> : null }
          { I18n.t( source ) }
          { postIconClass ? <i className={`${postIconClass} post-icon`}></i> : null }
        </div>
      </OverlayTrigger>
    );
  }
}

SourceChooserPopover.propTypes = {
  container: PropTypes.object,
  source: PropTypes.string,
  defaultSource: PropTypes.object,
  className: PropTypes.string,
  setSource: PropTypes.func,
  clearSource: PropTypes.func,
  preIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  postIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] )
};

SourceChooserPopover.defaultProps = {
  preIconClass: "fa fa-search",
  source: "observations"
};

export default SourceChooserPopover;
