/* global I18n */

// Pluralization rules for locales we support. Locales that use the "one" and
// "other" forms used in English will work by default, but everything else needs
// to be handled here.
// Mostly ported from https://github.com/svenfuchs/rails-i18n
( function ( ) {
  // Takes a count that might be a localized string with delimiters and turns it
  // into a number we can use for determining the right plural form
  function normalizeCount( count, locale ) {
    var separator = I18n.t( "number.format.separator", { locale: locale } );
    var delimiter = I18n.t( "number.format.delimiter", { locale: locale } );
    var pieces = count.toString().split( separator );
    var parsableString = pieces.join( "." );
    if ( pieces.length === 2 ) {
      parsableString = pieces[0].replace( delimiter, "" ) + "." + pieces[1];
    } else {
      parsableString = pieces[0].replace( delimiter, "" );
    }
    return parseFloat( parsableString );
  }

  // Common pluralization rules
  function eastSlavic( count, locale ) {
    var n = normalizeCount( count, locale ) || 0;
    var mod10 = n % 10;
    var mod100 = n % 100;
    var isWhole = parseInt( n, 0 ) === n;
    if ( mod10 === 1 && mod100 !== 11 ) {
      return ["one"];
    }
    if (
      ( mod10 >= 2 && mod10 <= 4 && isWhole )
      && !( mod100 >= 12 && mod100 <= 14 && isWhole )
    ) {
      return ["few"];
    }
    if (
      mod10 === 0
      || ( mod10 >= 5 && mod10 <= 9 && isWhole )
      || ( mod100 >= 11 && mod100 <= 14 && isWhole )
    ) {
      return ["many"];
    }
    return ["other"];
  }

  function westSlavic( count, locale ) {
    var n = normalizeCount( count, locale ) || 0;
    var isWhole = parseInt( n, 0 ) === n;
    if ( n === 1 ) return ["one"];
    if ( n >= 2 && n <= 4 && isWhole ) return ["few"];
    return ["other"];
  }

  function oneUptoTwoOther( count, locale ) {
    var n = normalizeCount( count, locale ) || 0;
    var isWhole = parseInt( n, 0 ) === n;
    return n && n >= 0 && n < 2 && isWhole ? ["one"] : ["other"];
  }

  function other( ) {
    return ["other"];
  }

  // Override default to deal with English-style delimiters
  I18n.pluralization.default = function ( count ) {
    switch ( normalizeCount( count, I18n.locale || "en" ) ) {
      case 0: return ["zero", "other"];
      case 1: return ["one"];
      default: return ["other"];
    }
  };

  // Add pluralization rules for locales
  I18n.pluralization.ar = function ( count ) {
    var n = normalizeCount( count, "ar" ) || 0;
    var mod100 = n % 100;
    var isWhole = parseInt( n, 0 ) === n;
    if ( n === 0 ) {
      return ["zero"];
    }
    if ( n === 1 ) {
      return ["one"];
    }
    if ( isWhole && mod100 >= 3 && mod100 <= 10 ) {
      return ["few"];
    }
    if ( isWhole && mod100 >= 11 && mod100 <= 99 ) {
      return ["many"];
    }
    return ["other"];
  };
  I18n.pluralization.br = function ( count ) {
    var n = normalizeCount( count, "br" ) || 0;
    var mod10 = n % 10;
    var mod100 = n % 100;
    if ( mod10 === 1 && [11, 71, 91].indexOf( mod100 ) < 0 ) {
      return ["one"];
    }
    if ( mod10 === 2 && [12, 72, 92].indexOf( mod100 ) < 0 ) {
      return ["two"];
    }
    if ( n % 1000000 === 0 && n !== 0 ) {
      return ["many"];
    }
    return ["other"];
  };
  I18n.pluralization.cs = function ( count ) { return westSlavic( count, "cs" ); };
  I18n.pluralization.fr = function ( count ) { return oneUptoTwoOther( count, "fr" ); };
  I18n.pluralization.id = other;
  I18n.pluralization.ja = other;
  I18n.pluralization.ko = other;
  I18n.pluralization.lt = function ( count ) {
    var n = normalizeCount( count, "lt" ) || 0;
    var mod10 = n % 10;
    var mod100 = n % 100;
    var isWhole = parseInt( n, 0 ) === n;
    if (
      mod10 === 1
      && !( mod100 >= 11 && mod100 <= 19 )
      && isWhole
    ) {
      return ["one"];
    }
    if (
      mod10 >= 2
      && mod10 <= 9
      && !( mod100 >= 11 && mod100 <= 19 )
      && isWhole
    ) {
      return ["few"];
    }
    return ["other"];
  };
  I18n.pluralization.mk = function ( count ) {
    var n = normalizeCount( count, "mk" ) || 0;
    var isWhole = parseInt( n, 0 ) === n;
    if (
      n % 10 === 1
      && n !== 11
      && isWhole
    ) {
      return ["one"];
    }
    return ["other"];
  };
  I18n.pluralization.pl = function ( count ) {
    var n = normalizeCount( count, "pl" ) || 0;
    var mod10 = n % 10;
    var mod100 = n % 100;
    var isWhole = parseInt( n, 0 ) === n;
    if ( n === 1 ) {
      return ["one"];
    }
    if (
      ( mod10 >= 2 && mod10 <= 4 )
      && !( mod100 >= 12 && mod100 <= 14 )
      && isWhole
    ) {
      return ["few"];
    }
    if (
      [0, 1, 5, 6, 7, 8, 9].indexOf( mod10 ) >= 0
      || [12, 13, 14].indexOf( mod100 ) >= 0
    ) {
      return ["many"];
    }
    return ["other"];
  };
  I18n.pluralization.ro = function ( count ) {
    var n = normalizeCount( count, "ro" ) || 0;
    var mod100 = n % 100;
    var isWhole = parseInt( n, 0 ) === n;
    if ( n === 1 ) {
      return ["one"];
    }
    if (
      n === 0
      || ( mod100 >= 1 && mod100 <= 19 && isWhole )
    ) {
      return ["few"];
    }
    return ["other"];
  };
  I18n.pluralization.ru = function ( count ) { return eastSlavic( count, "ru" ); };
  I18n.pluralization.sk = function ( count ) { return westSlavic( count, "sk" ); };
  I18n.pluralization.uk = function ( count ) { return eastSlavic( count, "uk" ); };
  I18n.pluralization.zh = other;
  I18n.pluralization["zh-CN"] = other;
  I18n.pluralization["zh-HK"] = other;
  I18n.pluralization["zh-TW"] = other;
}( ) );
