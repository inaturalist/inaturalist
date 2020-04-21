import React from "react";
import PropTypes from "prop-types";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import _ from "lodash";

class ChooserPopover extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      choices: props.choices,
      current: 0
    };
  }

  componentWillReceiveProps( newProps ) {
    const { choices } = this.state;
    this.setState( {
      current: choices.indexOf( newProps.chosen || newProps.defaultChoice )
    } );
  }

  chooseCurrent( ) {
    const { choices, current } = this.state;
    const { setChoice, clearChoice } = this.props;
    const currentChoice = choices[current];
    // Dumb, but I don't see a better way to explicity close the popover
    $( "body" ).click( );
    if ( currentChoice ) {
      setChoice( currentChoice );
    } else {
      clearChoice( );
    }
  }

  render( ) {
    const {
      id,
      container,
      chosen,
      defaultChoice,
      className,
      preIconClass,
      postIconClass,
      label,
      hideClear,
      choiceIconClass,
      choiceLabels
    } = this.props;
    const { current, choices } = this.state;
    return (
      <OverlayTrigger
        trigger="click"
        placement="bottom"
        rootClose
        container={container}
        overlay={(
          <Popover id={id} className="ChooserPopover RecordChooserPopover">
            <ul className="list-unstyled">
              { hideClear ? null : (
                <li
                  className={current === -1 ? "current pinned" : "pinned"}
                  onMouseOver={( ) => {
                    this.setState( { current: -1 } );
                  }}
                  onClick={( ) => this.chooseCurrent( )}
                  style={{ display: chosen ? "block" : "none" }}
                >
                  <i className="fa fa-times" />
                  { I18n.t( "clear" ) }
                </li>
              ) }
              { _.map( choices, ( s, i ) => (
                <li
                  key={`source-chooser-source-${s}`}
                  className={`media ${current === i ? "current" : ""}`}
                  onClick={( ) => this.chooseCurrent( )}
                  onMouseOver={( ) => {
                    this.setState( { current: i } );
                  }}
                >
                  <div className="media-left">
                    { choiceIconClass ? <i className={`media-object ${choiceIconClass}`} /> : null }
                  </div>
                  <div className="media-body">
                    { I18n.t( choiceLabels[s] || s ) }
                  </div>
                </li>
              ) ) }
            </ul>
          </Popover>
        )}
      >
        <div
          className={
            `ChooserPopoverTrigger RecordChooserPopoverTrigger ${chosen ? "chosen" : ""} ${className}`
          }
        >
          { preIconClass ? <i className={`${preIconClass} pre-icon`} /> : null }
          { label ? ( <label>{ label }</label> ) : null }
          { I18n.t( choiceLabels[chosen] || chosen
            || choiceLabels[defaultChoice] || defaultChoice ) }
          { postIconClass ? <i className={`${postIconClass} post-icon`} /> : null }
        </div>
      </OverlayTrigger>
    );
  }
}

ChooserPopover.propTypes = {
  id: PropTypes.string.isRequired,
  container: PropTypes.object,
  chosen: PropTypes.string,
  choices: PropTypes.array,
  choiceLabels: PropTypes.object,
  defaultChoice: PropTypes.string,
  className: PropTypes.string,
  setChoice: PropTypes.func,
  clearChoice: PropTypes.func,
  preIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  postIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  label: PropTypes.string,
  hideClear: PropTypes.bool,
  choiceIconClass: PropTypes.string
};

ChooserPopover.defaultProps = {
  preIconClass: "fa fa-search",
  choices: [],
  choiceLabels: {}
};

export default ChooserPopover;
