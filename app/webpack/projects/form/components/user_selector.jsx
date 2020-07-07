import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";

class UserSelector extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.userAutocomplete = React.createRef( );
  }

  render( ) {
    const {
      config,
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse
      ? I18n.t( "exclude_users" )
      : I18n.t( "include_users" );
    const rule = inverse ? "not_observed_by_user?" : "observed_by_user?";
    const rulesAttribute = inverse ? "notUserRules" : "userRules";
    return (
      <div className="UserSelector">
        <label>{ label }</label>
        <div className="input-group">
          <span className="input-group-addon fa fa-briefcase" />
          <UserAutocomplete
            ref={this.userAutocomplete}
            afterSelect={e => {
              e.item.id = e.item.user_id;
              addProjectRule( rule, "User", e.item );
              this.userAutocomplete.current.inputElement( ).val( "" );
            }}
            bootstrapClear
            config={config}
            placeholder={I18n.t( "user_autocomplete_placeholder" )}
          />
        </div>
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], userRule => (
              <div className="badge-div" key={`user_rule_${userRule.user.id}`}>
                <span className="badge">
                  { userRule.user.login }
                  <button
                    type="button"
                    className="btn btn-nostyle"
                    onClick={( ) => removeProjectRule( userRule )}
                  >
                    <i className="fa fa-times-circle-o" />
                  </button>

                </span>
              </div>
            ) ) }
          </div>
        ) }
      </div>
    );
  }
}

UserSelector.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func,
  inverse: PropTypes.bool
};

export default UserSelector;
