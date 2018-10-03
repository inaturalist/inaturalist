import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";

class UserSelector extends React.Component {
  render( ) {
    const {
      config,
      project,
      addProjectRule,
      removeProjectRule,
      inverse
    } = this.props;
    const label = inverse ?
      I18n.t( "exclude_x", { x: I18n.t( "users" ) } ) : I18n.t( "users" );
    const rule = inverse ? "not_observed_by_user?" : "observed_by_user?";
    const rulesAttribute = inverse ? "notUserRules" : "userRules";
    return (
      <div className="UserSelector">
        <label>{ label }</label>
        <div className="input-group">
          <span className="input-group-addon fa fa-briefcase"></span>
          <UserAutocomplete
            ref="ua"
            afterSelect={ e => {
              e.item.id = e.item.user_id;
              addProjectRule( rule, "User", e.item );
              this.refs.ua.inputElement( ).val( "" );
            } }
            bootstrapClear
            config={ config }
            placeholder={ I18n.t( "user_autocomplete_placeholder" ) }
          />
        </div>
        { !_.isEmpty( project[rulesAttribute] ) && (
          <div className="icon-previews">
            { _.map( project[rulesAttribute], userRule => (
              <div className="badge-div" key={ `user_rule_${userRule.user.id}` }>
                <span className="badge">
                  { userRule.user.login }
                  <i
                    className="fa fa-times-circle-o"
                    onClick={ ( ) => removeProjectRule( userRule ) }
                  />
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
