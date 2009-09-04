
if (appVersion < 5.5) {
  undefined = Undefined();

  ANON = "HTML:!"; // for anonymous content
  
  // Fix String.replace (Safari1.x/IE5.0).
  var GLOBAL = /(g|gi)$/;
  var _String_replace = String.prototype.replace; 
  String.prototype.replace = function(expression, replacement) {
    if (typeof replacement == "function") { // Safari doesn't like functions
      if (expression && expression.constructor == RegExp) {
        var regexp = expression;
        var global = regexp.global;
        if (global == null) global = GLOBAL.test(regexp);
        // we have to convert global RexpExps for exec() to work consistently
        if (global) regexp = new RegExp(regexp.source); // non-global
      } else {
        regexp = new RegExp(rescape(expression));
      }
      var match, string = this, result = "";
      while (string && (match = regexp.exec(string))) {
        result += string.slice(0, match.index) + replacement.apply(this, match);
        string = string.slice(match.index + match[0].length);
        if (!global) break;
      }
      return result + string;
    }
    return _String_replace.apply(this, arguments);
  };
  
  Array.prototype.pop = function() {
    if (this.length) {
      var i = this[this.length - 1];
      this.length--;
      return i;
    }
    return undefined;
  };
  
  Array.prototype.push = function() {
    for (var i = 0; i < arguments.length; i++) {
      this[this.length] = arguments[i];
    }
    return this.length;
  };
  
  var ns = this;
  Function.prototype.apply = function(o, a) {
    if (o === undefined) o = ns;
    else if (o == null) o = window;
    else if (typeof o == "string") o = new String(o);
    else if (typeof o == "number") o = new Number(o);
    else if (typeof o == "boolean") o = new Boolean(o);
    if (arguments.length == 1) a = [];
    else if (a[0] && a[0].writeln) a[0] = a[0].documentElement.document || a[0];
    var $ = "#ie7_apply", r;
    o[$] = this;
    switch (a.length) { // unroll for speed
      case 0: r = o[$](); break;
      case 1: r = o[$](a[0]); break;
      case 2: r = o[$](a[0],a[1]); break;
      case 3: r = o[$](a[0],a[1],a[2]); break;
      case 4: r = o[$](a[0],a[1],a[2],a[3]); break;
      case 5: r = o[$](a[0],a[1],a[2],a[3],a[4]); break;
      default:
        var b = [], i = a.length - 1;
        do b[i] = "a[" + i + "]"; while (i--);
        eval("r=o[$](" + b + ")");
    }
    if (typeof o.valueOf == "function") { // not a COM object
      delete o[$];
    } else {
      o[$] = undefined;
      if (r && r.writeln) r = r.documentElement.document || r;
    }
    return r;
  };
  
  Function.prototype.call = function(o) {
    return this.apply(o, _slice.apply(arguments, [1]));
  };

  // block elements are "inline" according to IE5.0 so we'll fix it
  HEADER += "address,blockquote,body,dd,div,dt,fieldset,form,"+
    "frame,frameset,h1,h2,h3,h4,h5,h6,iframe,noframes,object,p,"+
    "hr,applet,center,dir,menu,pre,dl,li,ol,ul{display:block}";
}
