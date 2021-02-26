import baseFetch from "cross-fetch";
import _ from "lodash";
import moment from "moment-timezone";

// Light wrapper around fetch to ensure credentials are always passed through
const fetch = ( url, options = {} ) => baseFetch( url, Object.assign( {}, options, {
  credentials: "same-origin"
} ) );

function updateSession( params ) {
  const data = new FormData( );
  data.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
  _.forEach( params, ( value, key ) => {
    data.append( key, value );
  } );
  fetch( "/users/update_session", {
    method: "PUT",
    body: data
  } );
}

// Basically serialize an object so it can be used for deep object comparison,
// e.g. when deciding whether to update a react component
function objectToComparable( object = {} ) {
  return _.map( _.keys( object ).sort( ), k => {
    const v = object[k];
    if ( typeof ( v ) === "object" ) {
      return `(${k}-${objectToComparable( v )})`;
    }
    if ( _.isNil( v ) ) {
      return `(${k}-)`;
    }
    return `(${k}-${v})`;
  } ).sort( ).join( "," );
}

function resizeUpload( file, opts, callback ) {
  const options = opts || { };
  options.quality = options.quality || 0.9;
  const reader = new FileReader( );
  reader.onload = readerEvent => {
    const image = new Image();
    image.onload = ( ) => {
      // Resize the image
      const canvas = document.createElement( "canvas" );
      const maxDimension = 400;
      let { width, height } = image;
      if ( width > height && width > maxDimension ) {
        height *= maxDimension / width;
        width = maxDimension;
      } else if ( height > maxDimension ) {
        width *= maxDimension / height;
        height = maxDimension;
      }
      canvas.width = width * 2;
      canvas.height = height * 2;
      const context = canvas.getContext( "2d" );
      context.scale( 2, 2 );
      context.drawImage( image, 0, 0, width, height );
      if ( options.blob ) {
        canvas.toBlob( callback, "image/jpeg", options.quality );
      } else {
        callback( canvas.toDataURL( "image/jpeg", options.quality ) );
      }
    };
    image.src = readerEvent.target.result;
  };
  reader.readAsDataURL( file );
}

function isBlank( val ) {
  return _.isNumber( val ) ? !_.isFinite( val ) : _.isEmpty( val );
}

function numberWithCommas( num ) {
  if ( !num && num !== 0 ) { return ""; }
  return I18n.toNumber( num, {
    precision: 0,
    separator: I18n.t( "number.format.separator" ),
    delimiter: I18n.t( "number.format.delimiter" )
  } );
}

// "legacy disagreement" might be a better term here. Basically this is
// "@loarie's code determining whether this would have been considered a
// "disagreement before we introduced explicit disagreements
const addImplicitDisagreementsToActivity = activity => {
  const taxonIDsDisplayed = { };
  return activity.map( item => {
    let firstDisplay;
    if ( item.taxon && item.current ) {
      firstDisplay = !taxonIDsDisplayed[item.taxon.id];
      taxonIDsDisplayed[item.taxon.id] = true;
    } else {
      return item;
    }
    let firstIdentOfTaxon = null;
    if ( item.taxon ) {
      firstIdentOfTaxon = _.filter(
        _.sortBy(
          _.filter( activity, ai => ( ai.taxon && ai.current ) ),
          ai => ai.id
        ),
        ai => ( _.intersection( ai.taxon.ancestor_ids, [item.taxon.id] ).length > 0 )
      )[0];
    }
    let implicitDisagreement = false;
    if (
      firstIdentOfTaxon
      && item.disagreement == null
      && item.id > firstIdentOfTaxon.id
    ) {
      implicitDisagreement = true;
    }
    item.firstDisplay = firstDisplay;
    item.implicitDisagreement = implicitDisagreement;
    return item;
  } );
};

const formattedDateTimeInTimeZone = ( dateTime, timeZone ) => {
  const d = moment.tz( dateTime, timeZone );
  let format = I18n.t( "momentjs.datetime_with_zone" );
  // For some time zones, moment cannot output something nice like PDT and
  // instead does something like -08. In this situations, we print a full offset
  // like -08:00 instead
  if ( parseInt( d.format( "z" ), 0 ) && parseInt( d.format( "z" ), 0 ) !== 0 ) {
    format = I18n.t( "momentjs.datetime_with_offset" );
  }
  return d.format( format );
};


const inatreact = {
  // Interpolate a translated string with React components as interpolation
  // variables. I18n-js accepts interpolations but will only return a string, so
  // if you want to have variables in that string that have complicated markup
  // or (worse) interactive elements, you're either screwed or you're forced to
  // patch together a bunch of smaller pieces of text in a way that makes the
  // whole impossible to translate.
  //
  // This method will accept a key and interpolations like I18n.t, but it will return an array.
  //
  // All React components passed in as interpolations *must* have keys
  //
  // Non-interpolation params like defaultValue are not supported.
  translate: ( key, interpolations = {} ) => {
    if ( _.size( interpolations ) === 0 ) {
      return I18n.t( key );
    }
    const stubInterpolations = {};
    const reactInterpolations = {};
    _.each( interpolations, ( v, k ) => {
      if ( typeof ( v ) === "object" || typeof ( v ) === "function" ) {
        stubInterpolations[k] = `{${k}}`;
        reactInterpolations[k] = v;
      } else {
        stubInterpolations[k] = v;
      }
    } );
    const stubTranslation = I18n.t( key, stubInterpolations );
    let arr = [stubTranslation];
    _.each( reactInterpolations, ( component, k ) => {
      _.each( arr, ( piece, i ) => {
        if ( typeof ( piece ) === "string" ) {
          const bits = piece.split( `{${k}}` );
          if ( bits.length === 2 ) {
            arr[i] = [
              bits[0],
              component,
              bits[1]
            ];
          }
        }
      } );
      arr = _.flatten( arr );
    } );
    return _.filter( _.flatten( arr ), i => typeof ( i ) !== "string" || i.length > 0 );
  }
};
inatreact.t = inatreact.translate;

const stripTags = text => text.replace( /<.+?>/g, "" );

const shortFormattedNumber = d => {
  if ( d >= 1000000000 ) {
    return I18n.t( "number.format.si.giga", { number: _.round( d / 1000000000, 3 ) } );
  }
  if ( d >= 1000000 ) {
    return I18n.t( "number.format.si.mega", { number: _.round( d / 1000000, 3 ) } );
  }
  if ( d >= 1000 ) {
    return I18n.t( "number.format.si.kilo", { number: _.round( d / 1000, 3 ) } );
  }
  return d;
};

const compactDecimalFormattedNumber = number => {
  // this is different from shortFormattedNumber, which uses the international metric system
  // it's basically a less sophisticated version of the compact notation Intl.NumberFormat uses
  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat
  const compactNotations = Object.keys( I18n.t( "compact_number_formatting", { locale: "en" } ) );
  let shortNumber;
  let roundUp = false;

  const lang = I18n.locale.split( "-" )[0];

  const formatEastAsianLangs = ( ) => {
    // special treatment for Chinese/Japanese/Korean
    // where large numbers are grouped by four (instead of three)
    // and start showing add'l digits from ten thousand (instead of one thousand)
    // https://github.com/unicode-cldr/cldr-numbers-modern/blob/master/main/zh/numbers.json
    let n;
    if ( number < 1e9 ) {
      n = number / 1e4;
    } else if ( number < 1e13 ) {
      n = number / 1e9;
    } else {
      n = number / 1e13;
    }
    return n;
  };

  const formatBasque = ( ) => {
    // large numbers are grouped by six digits
    // https://github.com/unicode-cldr/cldr-numbers-modern/blob/master/main/eu/numbers.json
    let n;
    if ( number < 1e6 ) {
      n = number;
    } else if ( number < 1e12 ) {
      n = number / 1e6;
    } else {
      n = number / 1e12;
    }
    return n;
  };

  const formatGalician = ( ) => {
    // thousands and billions don't have a symbol
    // millions and trillions represented with same pattern as English ( 0 M, 00 M, 000 M)
    // https://github.com/unicode-cldr/cldr-numbers-modern/blob/master/main/gl/numbers.json
    let n;
    if ( number < 1e6 ) {
      n = number;
    } else if ( number < 1e9 ) {
      n = number / 1e6;
    } else if ( number < 1e12 ) {
      n = number;
    } else {
      n = number / 1e12;
    }
    return n;
  };

  const format = ( ) => {
    // standard formatting for English and other Germanic/Romance languages
    // https://github.com/unicode-cldr/cldr-numbers-modern/blob/master/main/en/numbers.json
    let n;
    if ( number < 1e6 ) {
      if ( lang === "de" ) {
        // German denotes 100,000 as 100.000 and starts compact notation from 1M onwards
        // https://github.com/unicode-cldr/cldr-numbers-modern/blob/master/main/de/numbers.json
        n = number;
      } else {
        n = number / 1e3;
      }
    } else if ( number < 1e9 ) {
      n = number / 1e6;
    } else if ( number < 1e12 ) {
      n = number / 1e9;
    } else {
      n = number / 1e12;
    }
    return n;
  };

  // determine whether number needs to round up for proper formatting
  // (i.e. from 1000K to 1M, 1000M to 1B)
  const round = ( digits, length ) => shortNumber.toFixed( 0 ) === digits
    && shortNumber < length;

  if ( lang === "zh" || lang === "ja" || lang === "ko" ) {
    shortNumber = formatEastAsianLangs( );
    roundUp = round( 1e4, 1e13 );
  } else if ( lang === "eu" ) {
    shortNumber = formatBasque( );
    roundUp = round( 1e6, 1e12 );
  } else if ( lang === "gl" ) {
    shortNumber = formatGalician( );
    roundUp = shortNumber.toFixed( 0 ) === 1e3 && shortNumber === 1e9;
  } else {
    shortNumber = format( );
    roundUp = round( 1e3, 1e12 );
  }

  const { length } = number.toString( );

  const index = roundUp ? length - 3 : length - 4;
  const notationIndex = Math.min( index, compactNotations.length - 1 );

  return I18n.t(
    `compact_number_formatting.${compactNotations[notationIndex]}`, {
      count: roundUp ? 1 : I18n.toNumber( shortNumber, { precision: 0 } )
    }
  );
};

// Duplicating stylesheets/colors
const COLORS = {
  inatGreen: "#74ac00",
  inatGreenLight: "#a8cc09",
  needsIdYellow: "#FFEE91",
  needsIdYellowLight: "#85743D",
  bootstrapLinkColor: "#428BCA",
  otherLinkColor: "#337AB7",
  lightGrey: "#F7F7F7",
  borderGrey: "#DDD",
  failRed: "#D9534F",
  pageBackgroundGrey: "#f8f8f8",
  iconic: {
    Unknown: "#aaaaaa",
    Protozoa: "#691776",
    Plantae: "#73AC13",
    Fungi: "#ff1493",
    Animalia: "#1E90FF",
    Mollusca: "#FF4500",
    Arachnida: "#FF4500",
    Insecta: "#FF4500",
    Amphibia: "#1E90FF",
    Reptilia: "#1E90FF",
    Aves: "#1E90FF",
    Mammalia: "#1E90FF",
    Actinopterygii: "#1E90FF",
    Chromista: "#993300"
  },

  // 2019 branding guidelines colors
  successGreen: "#A8CC09",
  warningYellow: "#FFEE91",
  blue: "#2E78B8",
  darkGreen: "#228A22",
  orange: "#E66C39",
  mediumGray: "#999999",
  maroon: "#842203",
  purple: "#801A80",
  darkMagenta: "#AA0044",
  pink: "#E65C93",
  yellow: "#E6A939"
};

export {
  fetch,
  updateSession,
  objectToComparable,
  resizeUpload,
  isBlank,
  numberWithCommas,
  addImplicitDisagreementsToActivity,
  formattedDateTimeInTimeZone,
  COLORS,
  inatreact,
  stripTags,
  shortFormattedNumber,
  compactDecimalFormattedNumber
};
