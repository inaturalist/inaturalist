import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { scaleLinear, max as d3max } from "d3";

class Translators extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      initialNumToShow: props.perPage,
      sortBy: "total",
      sort: "desc"
    };
  }

  render( ) {
    const {
      data,
      perPage,
      siteName
    } = this.props;
    const {
      initialNumToShow,
      sort,
      sortBy
    } = this.state;
    let numToShow = initialNumToShow;
    const dataWithTotals = _.map( data.users, ( d, username ) => Object.assign( {}, d, {
      username,
      web: d.words_web || 0,
      mobile: d.words_mobile || 0,
      seek: d.words_seek || 0,
      total: ( d.words_web || 0 ) + ( d.words_mobile || 0 ) + ( d.words_seek || 0 )
    } ) );
    if ( !perPage && initialNumToShow < dataWithTotals.length ) {
      numToShow = dataWithTotals.length;
    }
    const sortedData = _.sortBy( dataWithTotals, u => u[sortBy] * ( sort === "asc" ? 1 : -1 ) );
    const dataToShow = sortedData.slice( 0, numToShow );
    const languageNames = _.keys( data.languages );
    const maxVal = d3max( _.map( dataWithTotals, d => d.total ) );
    const scale = scaleLinear( )
      .domain( [0, maxVal] )
      .range( [0, 1] );
    return (
      <div className="Translators">
        <h3>
          <a name="translators" href="#translators">
            <span>{ I18n.t( "views.stats.year.translators_title" ) }</span>
          </a>
        </h3>
        <p
          className="text-muted"
          dangerouslySetInnerHTML={{
            __html: siteName
              ? I18n.t( "views.stats.year.translators_desc_for_site", {
                site_name: siteName,
                x_people: I18n.t( "x_people", {
                  count: I18n.toNumber( _.size( dataWithTotals ), { precision: 0 } )
                } ),
                website_link_tag: `<a href='${window.location.origin}'>`,
                link_tag_end: "</a>",
                iphone_link_tag: "<a href='https://itunes.apple.com/us/app/inaturalist/id421397028?mt=8'>",
                android_link_tag: "<a href='https://play.google.com/store/apps/details?id=org.inaturalist.android'>",
                seek_link_tag: "<a href='https://www.inaturalist.org/seek'>",
                view_all_web_link_tag: "<a href='https://github.com/inaturalist/inaturalist/blob/main/config/locales/CONTRIBUTORS.md'>",
                view_all_mobile_link_tag: "<a href='https://github.com/inaturalist/iNaturalistAndroid/blob/main/iNaturalist/src/main/res/CONTRIBUTORS.md'>"
              } )
              : I18n.t( "views.stats.year.translators_desc", {
                x_languages: I18n.t( "x_languages", {
                  count: I18n.toNumber( languageNames.length, { precision: 0 } )
                } ),
                x_people: I18n.t( "x_people", {
                  count: I18n.toNumber( _.size( dataWithTotals ), { precision: 0 } )
                } ),
                website_link_tag: `<a href='${window.location.origin}'>`,
                link_tag_end: "</a>",
                iphone_link_tag: "<a href='https://itunes.apple.com/us/app/inaturalist/id421397028?mt=8'>",
                android_link_tag: "<a href='https://play.google.com/store/apps/details?id=org.inaturalist.android'>",
                seek_link_tag: "<a href='https://www.inaturalist.org/seek'>",
                view_all_web_link_tag: "<a href='https://github.com/inaturalist/inaturalist/blob/main/config/locales/CONTRIBUTORS.md'>",
                view_all_mobile_link_tag: "<a href='https://github.com/inaturalist/iNaturalistAndroid/blob/main/iNaturalist/src/main/res/CONTRIBUTORS.md'>"
              } )
          }}
        />
        <p
          className="text-muted"
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.stats.year.translators_prompt", {
              link_tag: "<a href='https://www.inaturalist.org/pages/translate'>",
              link_tag_end: "</a>"
            } )
          }}
        />
        <table className="table table-responsive">
          <thead>
            <tr>
              <th>{ I18n.t( "name" ) }</th>
              { ["website", "mobile", "seek", "total"].map( a => (
                <th
                  className={`number ${a === "total" ? "" : "hidden-xs hidden-sm"}`}
                  key={`translators-header-${a}`}
                >
                  <button
                    type="button"
                    onClick={( ) => this.setState( {
                      sortBy: a,
                      sort: a !== sortBy || sort === "asc" ? "desc" : "asc"
                    } )}
                  >
                    {
                      // I18n.t( "website" )
                      // I18n.t( "mobile" )
                      // I18n.t( "seek" )
                      // I18n.t( "total" )
                      I18n.t( a )
                    }
                    { sortBy === a && (
                      <i className={`fa fa-caret-${sort === "asc" ? "up" : "down"}`} />
                    ) }
                  </button>
                </th>
              ) ) }
              <th>{ I18n.t( "translated_languages" ) }</th>
            </tr>
          </thead>
          <tbody>
            { _.map( dataToShow, d => (
              <tr key={`translator-${d.name}`}>
                <td>
                  <a href={`https://crowdin.com/profile/${d.username}`}>
                    { d.name || d.username}
                  </a>
                </td>
                <td className="number hidden-xs hidden-sm">
                  <div
                    className="bar"
                    style={{ width: `${100 * scale( d.words_web || 0 )}%` }}
                  >
                    { I18n.toNumber( d.words_web || 0, { precision: 0 } ) }
                  </div>
                </td>
                <td className="number hidden-xs hidden-sm">
                  <div
                    className="bar"
                    style={{ width: `${100 * scale( d.words_mobile || 0 )}%` }}
                  >
                    { I18n.toNumber( d.words_mobile || 0, { precision: 0 } ) }
                  </div>
                </td>
                <td className="number hidden-xs hidden-sm">
                  <div
                    className="bar"
                    style={{ width: `${100 * scale( d.words_seek || 0 )}%` }}
                  >
                    { I18n.toNumber( d.words_seek || 0, { precision: 0 } ) }
                  </div>
                </td>
                <td className="number">
                  <div
                    className="bar"
                    style={{ width: `${100 * scale( d.total )}%` }}
                  >
                    { I18n.toNumber( d.total || 0, { precision: 0 } ) }
                  </div>
                </td>
                <td className="badges">
                  { d.languages.map( lang => data.languages[lang] ).map( l => (
                    <span
                      className="badge"
                      key={`langauge-${l.code}`}
                    >
                      { l.locale
                        ? I18n.t( `locales.${l.locale}`, { defaultValue: l.name } )
                        : l.name
                      }
                    </span>
                  ) ) }
                </td>
              </tr>
            ) ) }
          </tbody>
        </table>
        { dataWithTotals.length > numToShow && (
          <button
            type="button"
            className="btn btn-default btn-bordered center-block"
            onClick={() => {
              this.setState( {
                initialNumToShow: Math.min( dataWithTotals.length, initialNumToShow + perPage )
              } );
            }}
          >
            { I18n.t( "more_caps", { defaultValue: I18n.t( "more" ) } ) }
          </button>
        ) }
      </div>
    );
  }
}

Translators.propTypes = {
  data: PropTypes.object,
  perPage: PropTypes.number,
  siteName: PropTypes.string
};

Translators.defaultProps = {
  perPage: 10
};

export default Translators;
