import _ from "lodash";
import React, { PropTypes } from "react";
import UserImage from "../../identify/components/user_image";

class Identifiers extends React.Component {

  render( ) {
    if ( _.isEmpty( this.props.identifiers ) ) { return ( <span /> ); }
    const taxon = this.props.observation.taxon;
    return (
      <div className="Identifiers">
        <h4>
          Top Identifiers of { taxon.preferred_common_name || taxon.name }
        </h4>
        { this.props.identifiers.map( i => (
          <div className="identifier" key={ `identifier-${i.user.id}` }>
            <div className="UserWithIcon">
              <div className="icon">
                <UserImage user={ i.user } />
              </div>
              <div className="title">
                <a href={ `/people/${i.user.login}` }>{ i.user.login }</a>
              </div>
              <div className="subtitle">
                <i className="fa fa-tag" />
                { i.count }
              </div>
            </div>
          </div>
        ) ) }
      </div>
    );
  }
}

Identifiers.propTypes = {
  observation: PropTypes.object,
  identifiers: PropTypes.array
};

export default Identifiers;
