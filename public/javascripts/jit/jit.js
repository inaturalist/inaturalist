(function () { 

/*
  File: Core.js
  
  Description:
  
  Provides common utility functions and the Class object used internally by the library.
  
  Also provides the <TreeUtil> object for manipulating JSON tree structures
  
  Some parts of this Script are based on Mootools core: <http://mootools.net>
  
  Author: 
  
  Nicolas Garcia Belmonte
  
  Copyright: 
  
  Copyright 2008-2009 by Nicolas Garcia Belmonte.
  
  Homepage: 
  
  <http://thejit.org>
  
  Version: 
  
  1.1.0a

  License: 
  
  BSD License
 
> Redistribution and use in source and binary forms, with or without
> modification, are permitted provided that the following conditions are met:
>      * Redistributions of source code must retain the above copyright
>        notice, this list of conditions and the following disclaimer.
>      * Redistributions in binary form must reproduce the above copyright
>        notice, this list of conditions and the following disclaimer in the
>        documentation and/or other materials provided with the distribution.
>      * Neither the name of the organization nor the
>        names of its contributors may be used to endorse or promote products
>        derived from this software without specific prior written permission.
>
>  THIS SOFTWARE IS PROVIDED BY Nicolas Garcia Belmonte ``AS IS'' AND ANY
>  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
>  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
>  DISCLAIMED. IN NO EVENT SHALL Nicolas Garcia Belmonte BE LIABLE FOR ANY
>  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
>  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
>  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
>  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
>  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
>  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


function $empty() {};

function $extend(original, extended){
    for (var key in (extended || {})) original[key] = extended[key];
    return original;
};

function $lambda(value){
    return (typeof value == 'function') ? value : function(){
        return value;
    };
};

var $time = Date.now || function(){
    return +new Date;
};

function $splat(obj){
    var type = $type(obj);
    return (type) ? ((type != 'array') ? [obj] : obj) : [];
};

var $type = function(elem) {
	return $type.s.call(elem).match(/^\[object\s(.*)\]$/)[1].toLowerCase();
};
$type.s = Object.prototype.toString;

function $each(iterable, fn){
    var type = $type(iterable);
	if(type == 'object') {
		for (var key in iterable) fn(iterable[key], key);
	} else {
		for(var i=0; i < iterable.length; i++) fn(iterable[i], i);
	}
};

function $merge(){
    var mix = {};
    for (var i = 0, l = arguments.length; i < l; i++){
        var object = arguments[i];
        if ($type(object) != 'object') continue;
        for (var key in object){
            var op = object[key], mp = mix[key];
            mix[key] = (mp && $type(op) == 'object' && $type(mp) == 'object') ? $merge(mp, op) : $unlink(op);
        }
    }
    return mix;
};

function $unlink(object){
    var unlinked;
    switch ($type(object)){
        case 'object':
            unlinked = {};
            for (var p in object) unlinked[p] = $unlink(object[p]);
        break;
        case 'array':
            unlinked = [];
            for (var i = 0, l = object.length; i < l; i++) unlinked[i] = $unlink(object[i]);
        break;
        default: return object;
    }
    return unlinked;
};

function $rgbToHex(srcArray, array){
    if (srcArray.length < 3) return null;
    if (srcArray.length == 4 && srcArray[3] == 0 && !array) return 'transparent';
    var hex = [];
    for (var i = 0; i < 3; i++){
        var bit = (srcArray[i] - 0).toString(16);
        hex.push((bit.length == 1) ? '0' + bit : bit);
    }
    return (array) ? hex : '#' + hex.join('');
};

function $destroy(elem) {
   $clean(elem);
   if(elem.parentNode) elem.parentNode.removeChild(elem);
   if(elem.clearAttributes) elem.clearAttributes(); 
};

function $clean(elem) {
  for(var ch = elem.childNodes, i=0; i < ch.length; i++) {
      $destroy(ch[i]);
  }  
};

function $addEvent(obj, type, fn) {
    if (obj.addEventListener) 
        obj.addEventListener(type, fn, false);
    else 
        obj.attachEvent('on' + type, fn);
};

function $hasClass(obj, klass) {
    return (' ' + obj.className + ' ').indexOf(' ' + klass + ' ') > -1;
};

function $addClass(obj, klass) {
    if(!$hasClass(obj, klass)) obj.className = (obj.className + " " + klass);
};

function $removeClass(obj, klass) {
    obj.className = obj.className.replace(new RegExp('(^|\\s)' + klass + '(?:\\s|$)'), '$1');
};

function $get(id) {
  return document.getElementById(id);  
};

var Class = function(properties){
	properties = properties || {};
	var klass = function(){
//      not defining any attributes in Class properties.
//		for (var key in this){
//	        if (typeof this[key] != 'function') this[key] = $unlink(this[key]);
//	    }
	    this.constructor = klass;
	    if (Class.prototyping) return this;
	    var instance = (this.initialize) ? this.initialize.apply(this, arguments) : this;
	    return instance;
	};
	
	for (var mutator in Class.Mutators){
	    if (!properties[mutator]) continue;
	    properties = Class.Mutators[mutator](properties, properties[mutator]);
	    delete properties[mutator];
	}
	
	$extend(klass, this);
	klass.constructor = Class;
	klass.prototype = properties;
	return klass;
};

Class.Mutators = {

    Extends: function(self, klass){
        Class.prototyping = klass.prototype;
        var subclass = new klass;
        delete subclass.parent;
        subclass = Class.inherit(subclass, self);
        delete Class.prototyping;
        return subclass;
    },

    Implements: function(self, klasses){
        $each($splat(klasses), function(klass){
            Class.prototying = klass;
            $extend(self, ($type(klass) == 'function') ? new klass : klass);
            delete Class.prototyping;
        });
        return self;
    }

};

$extend(Class, {

    inherit: function(object, properties){
        var caller = arguments.callee.caller;
        for (var key in properties){
            var override = properties[key];
            var previous = object[key];
            var type = $type(override);
            if (previous && type == 'function'){
                if (override != previous){
                    if (caller){
                        override.__parent = previous;
                        object[key] = override;
                    } else {
                        Class.override(object, key, override);
                    }
                }
            } else if(type == 'object'){
                object[key] = $merge(previous, override);
            } else {
                object[key] = override;
            }
        }

        if (caller) object.parent = function(){
            return arguments.callee.caller.__parent.apply(this, arguments);
        };

        return object;
    },

    override: function(object, name, method){
        var parent = Class.prototyping;
        if (parent && object[name] != parent[name]) parent = null;
        var override = function(){
            var previous = this.parent;
            this.parent = parent ? parent[name] : object[name];
            var value = method.apply(this, arguments);
            this.parent = previous;
            return value;
        };
        object[name] = override;
    }

});


Class.prototype.implement = function(){
    var proto = this.prototype;
    $each(Array.prototype.slice.call(arguments || []), function(properties){
        Class.inherit(proto, properties);
    });
    return this;
};

/*
   Object: TreeUtil

   Some common JSON tree manipulation methods.
*/
this.TreeUtil = {

    /*
       Method: prune
    
       Clears all tree nodes having depth greater than maxLevel.
    
       Parameters:
    
          tree - A JSON tree object. For more information please see <Loader.loadJSON>.
          maxLevel - An integer specifying the maximum level allowed for this tree. All nodes having depth greater than max level will be deleted.

    */
    prune: function(tree, maxLevel) {
        this.each(tree, function(elem, i) {
            if(i == maxLevel && elem.children) {
                delete elem.children;
                elem.children = [];
            }
        });
    },
    
    /*
       Method: getParent
    
       Returns the parent node of the node having _id_ as id.
    
       Parameters:
    
          tree - A JSON tree object. See also <Loader.loadJSON>.
          id - The _id_ of the child node whose parent will be returned.

      Returns:

          A tree JSON node if any, or false otherwise.
    
    */
    getParent: function(tree, id) {
        if(tree.id == id) return false;
        var ch = tree.children;
        if(ch && ch.length > 0) {
            for(var i=0; i<ch.length; i++) {
                if(ch[i].id == id) 
                    return tree;
                else {
                    var ans = this.getParent(ch[i], id);
                    if(ans) return ans;
                }
            }
        }
        return false;       
    },

    /*
       Method: getSubtree
    
       Returns the subtree that matches the given id.
    
       Parameters:
    
          tree - A JSON tree object. See also <Loader.loadJSON>.
          id - A node *unique* identifier.
    
       Returns:
    
          A subtree having a root node matching the given id. Returns null if no subtree matching the id is found.

    */
    getSubtree: function(tree, id) {
        if(tree.id == id) return tree;
        for(var i=0, ch=tree.children; i<ch.length; i++) {
            var t = this.getSubtree(ch[i], id);
            if(t != null) return t;
        }
        return null;
    },

    /*
       Method: getLeaves
    
        Returns the leaves of the tree.
    
       Parameters:
    
          node - A JSON tree node. See also <Loader.loadJSON>.
          maxLevel - _optional_ A subtree's max level.
    
       Returns:
    
       An array having objects with two properties. 
       
        - The _node_ property contains the leaf node. 
        - The _level_ property specifies the depth of the node.

    */
    getLeaves: function (node, maxLevel) {
        var leaves = [], levelsToShow = maxLevel || Number.MAX_VALUE;
        this.each(node, function(elem, i) {
            if(i < levelsToShow && 
            (!elem.children || elem.children.length == 0 )) {
                leaves.push({
                    'node':elem,
                    'level':levelsToShow - i
                });
            }
        });
        return leaves;
    },


    /*
       Method: eachLevel
    
        Iterates on tree nodes with relative depth less or equal than a specified level.
    
       Parameters:
    
          tree - A JSON tree or subtree. See also <Loader.loadJSON>.
          initLevel - An integer specifying the initial relative level. Usually zero.
          toLevel - An integer specifying a top level. This method will iterate only through nodes with depth less than or equal this number.
          action - A function that receives a node and an integer specifying the actual level of the node.
            
      Example:
     (start code js)
       TreeUtil.eachLevel(tree, 0, 3, function(node, depth) {
          alert(node.name + ' ' + depth);
       });
     (end code)
    */
    eachLevel: function(tree, initLevel, toLevel, action) {
        if(initLevel <= toLevel) {
            action(tree, initLevel);
            for(var i=0, ch = tree.children; i<ch.length; i++) {
                this.eachLevel(ch[i], initLevel +1, toLevel, action);   
            }
        }
    },

    /*
       Method: each
    
        A tree iterator.
    
       Parameters:
    
          tree - A JSON tree or subtree. See also <Loader.loadJSON>.
          action - A function that receives a node.

      Example:
      (start code js)
        TreeUtil.each(tree, function(node) {
          alert(node.name);
        });
      (end code)
            
    */
    each: function(tree, action) {
        this.eachLevel(tree, 0, Number.MAX_VALUE, action);
    },
    
    /*
       Method: loadSubtrees
    
        Appends subtrees to leaves by requesting new subtrees
        with the _request_ method.
    
       Parameters:
    
          tree - A JSON tree node. <Loader.loadJSON>.
          controller - An object that implements a request method.
      
       Example:
        (start code js)
          TreeUtil.loadSubtrees(leafNode, {
            request: function(nodeId, level, onComplete) {
              //Pseudo-code to make an ajax request for a new subtree
              // that has as root id _nodeId_ and depth _level_ ...
              Ajax.request({
                'url': 'http://subtreerequesturl/',
                
                onSuccess: function(json) {
                  onComplete.onComplete(nodeId, json);
                }
              });
            }
          });
        (end code)
    */
    loadSubtrees: function(tree, controller) {
        var maxLevel = controller.request && controller.levelsToShow;
        var leaves = this.getLeaves(tree, maxLevel),
        len = leaves.length,
        selectedNode = {};
        if(len == 0) controller.onComplete();
        for(var i=0, counter=0; i<len; i++) {
            var leaf = leaves[i], id = leaf.node.id;
            selectedNode[id] = leaf.node;
            controller.request(id, leaf.level, {
                onComplete: function(nodeId, tree) {
                    var ch = tree.children;
                    selectedNode[nodeId].children = ch;
                    if(++counter == len) {
                        controller.onComplete();
                    }
                }
            });
        }
    }
};



/*
 * File: Canvas.js
 *
 * A cross browser Canvas widget.
 *
 * Used By:
 *
 * <ST>, <Hypertree>, <RGraph>
 */
/*
 Class: Canvas
 A multi-purpose Canvas Class. This Class can be used with the ExCanvas library to provide
 cross browser Canvas based visualizations.
 Parameters:
 id - The canvas id. This id will be used as prefix for the canvas widget DOM elements ids.
 options - An object containing multiple options such as
 
 - _injectInto_ This property is _required_ and it specifies the id of the DOM element
 to which the Canvas widget will be appended
 - _width_ The width of the Canvas widget. Default's to 200px
 - _height_ The height of the Canvas widget. Default's to 200px
 - _backgroundColor_ Used for compatibility with IE. The canvas' background color.
 Default's to '#333'
 - _styles_ A hash containing canvas specific style properties such as _fillStyle_ and _strokeStyle_ among others.
 Example:
 Suppose we have this HTML
 (start code xml)
 <div id="infovis"></div>
 (end code)
 Now we create a new Canvas instance
 (start code js)
 //Create a new canvas instance
 var canvas = new Canvas('mycanvas', {
 //Where to inject the canvas. Any div container will do.
 'injectInto':'infovis',
 //width and height for canvas. Default's to 200.
 'width': 900,
 'height':500,
 //Canvas styles
 'styles': {
 'fillStyle': '#ccddee',
 'strokeStyle': '#772277'
 }
 });
 (end code)
 The generated HTML will look like this
 (start code xml)
 <div id="infovis">
 <div id="mycanvas" style="position:relative;">
 <canvas id="mycanvas-canvas" width=900 height=500
 style="position:absolute; top:0; left:0; width:900px; height:500px;" />
 <div id="mycanvas-label"
 style="overflow:visible; position:absolute; top:0; left:0; width:900px; height:0px">
 </div>
 </div>
 </div>
 (end code)
 As you can see, the generated HTML consists of a canvas DOM element of id _mycanvas-canvas_ and a div label container
 of id _mycanvas-label_, wrapped in a main div container of id _mycanvas_.
 You can also add a background canvas, for making background drawings.
 This is how the <RGraph> background concentric circles are drawn
 Example:
 (start code js)
 //Create a new canvas instance.
 var canvas = new Canvas('mycanvas', {
 //Where to inject the canvas. Any div container will do.
 'injectInto':'infovis',
 //width and height for canvas. Default's to 200.
 'width': 900,
 'height':500,
 //Canvas styles
 'styles': {
 'fillStyle': '#ccddee',
 'strokeStyle': '#772277'
 },
 //Add a background canvas for plotting
 //concentric circles.
 'backgroundCanvas': {
 //Add Canvas styles for the bck canvas.
 'styles': {
 'fillStyle': '#444',
 'strokeStyle': '#444'
 },
 //Add the initialization and plotting functions.
 'impl': {
 'init': function() {},
 'plot': function(canvas, ctx) {
 var times = 6, d = 100;
 var pi2 = Math.PI*2;
 for(var i=1; i<=times; i++) {
 ctx.beginPath();
 ctx.arc(0, 0, i * d, 0, pi2, true);
 ctx.stroke();
 ctx.closePath();
 }
 }
 }
 }
 });
 (end code)
 The _backgroundCanvas_ object contains a canvas _styles_ property and
 an _impl_ key to be used for implementing background canvas specific code.
 The _init_ method is only called once, at the instanciation of the background canvas.
 The _plot_ method is called for plotting a Canvas image.
 */
this.Canvas = (function(){
    var config = {
        'injectInto': 'id',
        
        'width': 200,
        'height': 200,
        
        'backgroundColor': '#333333',
        
        'styles': {
            'fillStyle': '#000000',
            'strokeStyle': '#000000'
        },
        
        'backgroundCanvas': false
    };
    
    function hasCanvas(){
        hasCanvas.t = hasCanvas.t || typeof(HTMLCanvasElement);
        return "function" == hasCanvas.t || "object" == hasCanvas.t;
    };
    
    function create(tag, prop, styles){
        var elem = document.createElement(tag);
        (function(obj, prop){
            if (prop) 
                for (var p in prop) 
                    obj[p] = prop[p];
            return arguments.callee;
        })(elem, prop)(elem.style, styles);
        //feature check
        if (tag == "canvas" && !hasCanvas() && G_vmlCanvasManager) {
            elem = G_vmlCanvasManager.initElement(document.body.appendChild(elem));
        }
        
        return elem;
    };
    
    function get(id){
        return document.getElementById(id);
    };
    
    function translateToCenter(canvas, ctx, w, h){
        var width = w ? (w - canvas.width) : canvas.width;
        var height = h ? (h - canvas.height) : canvas.height;
        ctx.translate(width / 2, height / 2);
    };
    
    return function(id, opt){
        var ctx, bkctx, mainContainer, labelContainer, canvas, bkcanvas;
        if (arguments.length < 1) 
            throw "Arguments missing";
        var idLabel = id + "-label", idCanvas = id + "-canvas", idBCanvas = id + "-bkcanvas";
        opt = $merge(config, opt ||
        {});
        //create elements
        var dim = {
            'width': opt.width,
            'height': opt.height
        };
        mainContainer = create("div", {
            'id': id
        }, $merge(dim, {
            'position': 'relative'
        }));
        labelContainer = create("div", {
            'id': idLabel
        }, {
            'overflow': 'visible',
            'position': 'absolute',
            'top': 0,
            'left': 0,
            'width': dim.width + 'px',
            'height': 0
        });
        var dimPos = {
            'position': 'absolute',
            'top': 0,
            'left': 0,
            'width': dim.width + 'px',
            'height': dim.height + 'px'
        };
        canvas = create("canvas", $merge({
            'id': idCanvas
        }, dim), dimPos);
        var bc = opt.backgroundCanvas;
        if (bc) {
            bkcanvas = create("canvas", $merge({
                'id': idBCanvas
            }, dim), dimPos);
            //append elements
            mainContainer.appendChild(bkcanvas);
        }
        mainContainer.appendChild(canvas);
        mainContainer.appendChild(labelContainer);
        get(opt.injectInto).appendChild(mainContainer);
        
        //create contexts
        ctx = canvas.getContext('2d');
        translateToCenter(canvas, ctx);
        var st = opt.styles;
        for (var s in st) 
            ctx[s] = st[s];
        if (bc) {
            bkctx = bkcanvas.getContext('2d');
            var st = bc.styles;
            for (var s in st) 
                bkctx[s] = st[s];
            translateToCenter(bkcanvas, bkctx);
            bc.impl.init(bkcanvas, bkctx);
            bc.impl.plot(bkcanvas, bkctx);
        }
        //create methods
        return {
            'id': id,
            /*
             Method: getCtx
             
             Returns the main canvas context object
             Returns:
             
             Main canvas context
             Example:
             (start code js)
             var ctx = canvas.getCtx();
             //Now I can use the native canvas context
             //and for example change some canvas styles
             ctx.globalAlpha = 1;
             (end code)
             */
            getCtx: function(){
                return ctx;
            },
            
            /*
             Method: getElement
             Returns the main Canvas DOM wrapper
             
             Returns:
             
             DOM canvas wrapper generated, (i.e the div wrapper element with id _mycanvas_)
             Example:
             (start code js)
             var wrapper = canvas.getElement();
             //Returns <div id="mycanvas" ... >...</div> as element
             (end code)
             */
            getElement: function(){
                return mainContainer;
            },
            
            /*
             Method: resize
             
             Resizes the canvas.
             
             Parameters:
             
             width - New canvas width.
             height - New canvas height.
             This method can be used with the <ST>, <Hypertree> or <RGraph> visualizations to resize
             the visualizations
             Example:
             (start code js)
             function resizeViz(width, height) {
             canvas.resize(width, height);
             rgraph.refresh(); //ht.refresh or st.refresh() also work.
             rgraph.onAfterCompute();
             }
             (end code)
             
             */
            resize: function(width, height){
                canvas.width = width;
                canvas.height = height;
                canvas.style.width = width + "px";
                canvas.style.height = height + "px";
                if (bc) {
                    bkcanvas.width = width;
                    bkcanvas.height = height;
                    bkcanvas.style.width = width + "px";
                    bkcanvas.style.height = height + "px";
                }
                translateToCenter(canvas, ctx);
                var st = opt.styles;
                for (var s in st) 
                    ctx[s] = st[s];
                if (bc) {
                    var st = bc.styles;
                    for (var s in st) 
                        bkctx[s] = st[s];
                    translateToCenter(bkcanvas, bkctx);
                    bc.impl.init(bkcanvas, bkctx);
                    bc.impl.plot(bkcanvas, bkctx);
                }
            },
            
            /*
             Method: getSize
             
             Returns canvas dimensions.
             
             Returns:
             
             An object with _width_ and _height_ properties.
             Example:
             (start code js)
             canvas.getSize(); //returns { width: 900, height: 500 }
             (end code)
             */
            getSize: function(){
                return {
                    'width': canvas.width,
                    'height': canvas.height
                };
            },
            
            path: function(type, action){
                ctx.beginPath();
                action(ctx);
                ctx[type]();
                ctx.closePath();
            },
            
            /*
             Method: clear
             
             Clears the canvas object.
             */
            clear: function(){
                var size = this.getSize();
                ctx.clearRect(-size.width / 2, -size.height / 2, size.width, size.height);
            },
            
            /*
             Method: clearReactangle
             
             Same as <Canvas.clear> but only clears a section of the canvas.
             
             Parameters:
             
             top - An integer specifying the top of the rectangle.
             right -  An integer specifying the right of the rectangle.
             bottom - An integer specifying the bottom of the rectangle.
             left - An integer specifying the left of the rectangle.
             */
            clearRectangle: function(top, right, bottom, left){
                //if using excanvas
                if (!hasCanvas()) {
                    var f0 = ctx.fillStyle;
                    ctx.fillStyle = opt.backgroundColor;
                    ctx.fillRect(left, top, Math.abs(right - left), Math.abs(bottom - top));
                    ctx.fillStyle = f0;
                }
                else {
                    ctx.clearRect(left, top, Math.abs(right - left), Math.abs(bottom - top));
                }
            }
        };
    };
    
})();



/*
 * File: Polar.js
 * 
 * Defines the <Polar> class.
 *
 * Description:
 *
 * The <Polar> class, just like the <Complex> class, is used by the <Hypertree>, <ST> and <RGraph> as a 2D point representation.
 *
 * See also:
 *
 * <http://en.wikipedia.org/wiki/Polar_coordinates>
 *
*/

/*
   Class: Polar

   A multi purpose polar representation.

   Description:
 
   The <Polar> class, just like the <Complex> class, is used by the <Hypertree>, <ST> and <RGraph> as a 2D point representation.
 
   See also:
 
   <http://en.wikipedia.org/wiki/Polar_coordinates>
 
   Parameters:

      theta - An angle.
      rho - The norm.
*/

this.Polar = function(theta, rho) {
	this.theta = theta;
	this.rho = rho;
};

Polar.prototype = {
    /*
       Method: getc
    
       Returns a complex number.
    
       Parameters:

       simple - _optional_ If *true*, this method will return only an object holding x and y properties and not a <Complex> instance. Default's *false*.

      Returns:
    
          A complex number.
    */
    getc: function(simple) {
        return this.toComplex(simple);
    },

    /*
       Method: getp
    
       Returns a <Polar> representation.
    
       Returns:
    
          A variable in polar coordinates.
    */
    getp: function() {
        return this;
    },


    /*
       Method: set
    
       Sets a number.

       Parameters:

       v - A <Complex> or <Polar> instance.
    
    */
    set: function(v) {
        v = v.getp();
        this.theta = v.theta; this.rho = v.rho;
    },

    /*
       Method: setc
    
       Sets a <Complex> number.

       Parameters:

       x - A <Complex> number real part.
       y - A <Complex> number imaginary part.
    
    */
    setc: function(x, y) {
        this.rho = Math.sqrt(x * x + y * y);
        this.theta = Math.atan2(y, x);
        if(this.theta < 0) this.theta += Math.PI * 2;
    },

    /*
       Method: setp
    
       Sets a polar number.

       Parameters:

       theta - A <Polar> number angle property.
       rho - A <Polar> number rho property.
    
    */
    setp: function(theta, rho) {
        this.theta = theta; 
        this.rho = rho;
    },

    /*
       Method: clone
    
       Returns a copy of the current object.
    
       Returns:
    
          A copy of the real object.
    */
    clone: function() {
        return new Polar(this.theta, this.rho);
    },

    /*
       Method: toComplex
    
        Translates from polar to cartesian coordinates and returns a new <Complex> instance.
    
        Parameters:

        simple - _optional_ If *true* this method will only return an object with x and y properties (and not the whole <Complex> instance). Default's *false*.
 
        Returns:
    
          A new <Complex> instance.
    */
    toComplex: function(simple) {
        var x = Math.cos(this.theta) * this.rho;
        var y = Math.sin(this.theta) * this.rho;
        if(simple) return { 'x': x, 'y': y};
        return new Complex(x, y);
    },

    /*
       Method: add
    
        Adds two <Polar> instances.
    
       Parameters:

       polar - A <Polar> number.

       Returns:
    
          A new Polar instance.
    */
    add: function(polar) {
        return new Polar(this.theta + polar.theta, this.rho + polar.rho);
    },
    
    /*
       Method: scale
    
        Scales a polar norm.
    
        Parameters:

        number - A scale factor.
        
        Returns:
    
          A new Polar instance.
    */
    scale: function(number) {
        return new Polar(this.theta, this.rho * number);
    },
    
    /*
       Method: equals
    
       Comparison method.

       Returns *true* if the theta and rho properties are equal.

       Parameters:

       c - A <Polar> number.

       Returns:

       *true* if the theta and rho parameters for these objects are equal. *false* otherwise.
    */
    equals: function(c) {
        return this.theta == c.theta && this.rho == c.rho;
    },
    
    /*
       Method: $add
    
        Adds two <Polar> instances affecting the current object.
    
       Paramters:

       polar - A <Polar> instance.

       Returns:
    
          The changed object.
    */
    $add: function(polar) {
        this.theta = this.theta + polar.theta; this.rho += polar.rho;
        return this;
    },

    /*
       Method: $madd
    
        Adds two <Polar> instances affecting the current object. The resulting theta angle is modulo 2pi.
    
       Parameters:

       polar - A <Polar> instance.

       Returns:
    
          The changed object.
    */
    $madd: function(polar) {
        this.theta = (this.theta + polar.theta) % (Math.PI * 2); this.rho += polar.rho;
        return this;
    },

    
    /*
       Method: $scale
    
        Scales a polar instance affecting the object.
    
      Parameters:

      number - A scaling factor.

      Returns:
    
          The changed object.
    */
    $scale: function(number) {
        this.rho *= number;
        return this;
    },
    
    /*
       Method: interpolate
    
        Calculates a polar interpolation between two points at a given delta moment.

        Parameters:
      
        elem - A <Polar> instance.
        delta - A delta factor ranging [0, 1].
    
       Returns:
    
          A new <Polar> instance representing an interpolation between _this_ and _elem_
    */
    interpolate: function(elem, delta) {
        var pi = Math.PI, pi2 = pi * 2;
        var ch = function(t) {
            return (t < 0)? (t % pi2) + pi2 : t % pi2;
        };
        var tt = this.theta, et = elem.theta;
        var sum;
        if(Math.abs(tt - et) > pi) {
            if(tt > et) {
                sum =ch((et + ((tt - pi2) - et) * delta)) ;
            } else {
                sum =ch((et - pi2 + (tt - (et - pi2)) * delta));
            }
        } else {
            sum =ch((et + (tt - et) * delta)) ;
        }
        var r = (this.rho - elem.rho) * delta + elem.rho;
        return {
            'theta': sum,
            'rho': r
        };
    }
};


var $P = function(a, b) { return new Polar(a, b); };

Polar.KER = $P(0, 0);



/*
 * File: Complex.js
 * 
 * Defines the <Complex> class.
 *
 * Description:
 *
 * The <Complex> class, just like the <Polar> class, is used by the <Hypertree>, <ST> and <RGraph> as a 2D point representation.
 *
 * See also:
 *
 * <http://en.wikipedia.org/wiki/Complex_number>
 *
*/

/*
   Class: Complex
    
   A multi-purpose Complex Class with common methods.
 
   Description:
 
   The <Complex> class, just like the <Polar> class, is used by the <Hypertree>, <ST> and <RGraph> as a 2D point representation.
 
   See also:
 
   <http://en.wikipedia.org/wiki/Complex_number>

   Parameters:

   x - _optional_ A Complex number real part.
   y - _optional_ A Complex number imaginary part.
 
*/

this.Complex = function(x, y) {
	this.x = x;
	this.y = y;
};

Complex.prototype = {
    /*
       Method: getc
    
       Returns a complex number.
    
       Returns:
    
          A complex number.
    */
    getc: function() {
        return this;
    },

    /*
       Method: getp
    
       Returns a <Polar> representation of this number.
    
       Parameters:

       simple - _optional_ If *true*, this method will return only an object holding theta and rho properties and not a <Polar> instance. Default's *false*.

       Returns:
    
          A variable in <Polar> coordinates.
    */
    getp: function(simple) {
        return this.toPolar(simple);
    },


    /*
       Method: set
    
       Sets a number.

       Parameters:

       c - A <Complex> or <Polar> instance.
    
    */
    set: function(c) {
        c = c.getc(true);
        this.x = c.x; 
		this.y = c.y;
    },

    /*
       Method: setc
    
       Sets a complex number.

       Parameters:

       x - A <Complex> number Real part.
       y - A <Complex> number Imaginary part.
    
    */
    setc: function(x, y) {
        this.x = x; 
        this.y = y;
    },

    /*
       Method: setp
    
       Sets a polar number.

       Parameters:

       theta - A <Polar> number theta property.
       rho - A <Polar> number rho property.
    
    */
    setp: function(theta, rho) {
        this.x = Math.cos(theta) * rho
        this.y = Math.sin(theta) * rho;
    },

    /*
       Method: clone
    
       Returns a copy of the current object.
    
       Returns:
    
          A copy of the real object.
    */
    clone: function() {
        return new Complex(this.x, this.y);
    },

    /*
       Method: toPolar
    
       Transforms cartesian to polar coordinates.
    
       Parameters:

       simple - _optional_ If *true* this method will only return an object with theta and rho properties (and not the whole <Polar> instance). Default's *false*.
       
       Returns:
    
          A new <Polar> instance.
    */
    
    toPolar: function(simple) {
        var rho = this.norm();
        var atan = Math.atan2(this.y, this.x);
        if(atan < 0) atan += Math.PI * 2;
        if(simple) return { 'theta': atan, 'rho': rho };
        return new Polar(atan, rho);
    },
    /*
       Method: norm
    
       Calculates a <Complex> number norm.
    
       Returns:
    
          A real number representing the complex norm.
    */
    norm: function () {
        return Math.sqrt(this.squaredNorm());
    },
    
    /*
       Method: squaredNorm
    
       Calculates a <Complex> number squared norm.
    
       Returns:
    
          A real number representing the complex squared norm.
    */
    squaredNorm: function () {
        return this.x*this.x + this.y*this.y;
    },

    /*
       Method: add
    
       Returns the result of adding two complex numbers.
       
       Does not alter the original object.

       Parameters:
    
          pos - A <Complex> instance.
    
       Returns:
    
         The result of adding two complex numbers.
    */
    add: function(pos) {
        return new Complex(this.x + pos.x, this.y + pos.y);
    },

    /*
       Method: prod
    
       Returns the result of multiplying two <Complex> numbers.
       
       Does not alter the original object.

       Parameters:
    
          pos - A <Complex> instance.
    
       Returns:
    
         The result of multiplying two complex numbers.
    */
    prod: function(pos) {
        return new Complex(this.x*pos.x - this.y*pos.y, this.y*pos.x + this.x*pos.y);
    },

    /*
       Method: conjugate
    
       Returns the conjugate of this <Complex> number.

       Does not alter the original object.

       Returns:
    
         The conjugate of this <Complex> number.
    */
    conjugate: function() {
        return new Complex(this.x, -this.y);
    },


    /*
       Method: scale
    
       Returns the result of scaling a <Complex> instance.
       
       Does not alter the original object.

       Parameters:
    
          factor - A scale factor.
    
       Returns:
    
         The result of scaling this complex to a factor.
    */
    scale: function(factor) {
        return new Complex(this.x * factor, this.y * factor);
    },

    /*
       Method: equals
    
       Comparison method.

       Returns *true* if both real and imaginary parts are equal.

       Parameters:

       c - A <Complex> instance.

       Returns:

       A boolean instance indicating if both <Complex> numbers are equal.
    */
    equals: function(c) {
        return this.x == c.x && this.y == c.y;
    },

    /*
       Method: $add
    
       Returns the result of adding two <Complex> numbers.
       
       Alters the original object.

       Parameters:
    
          pos - A <Complex> instance.
    
       Returns:
    
         The result of adding two complex numbers.
    */
    $add: function(pos) {
        this.x += pos.x; this.y += pos.y;
        return this;    
    },
    
    /*
       Method: $prod
    
       Returns the result of multiplying two <Complex> numbers.
       
       Alters the original object.

       Parameters:
    
          pos - A <Complex> instance.
    
       Returns:
    
         The result of multiplying two complex numbers.
    */
    $prod:function(pos) {
        var x = this.x, y = this.y
        this.x = x*pos.x - y*pos.y;
        this.y = y*pos.x + x*pos.y;
        return this;
    },
    
    /*
       Method: $conjugate
    
       Returns the conjugate for this <Complex>.
       
       Alters the original object.

       Returns:
    
         The conjugate for this complex.
    */
    $conjugate: function() {
        this.y = -this.y;
        return this;
    },
    
    /*
       Method: $scale
    
       Returns the result of scaling a <Complex> instance.
       
       Alters the original object.

       Parameters:
    
          factor - A scale factor.
    
       Returns:
    
         The result of scaling this complex to a factor.
    */
    $scale: function(factor) {
        this.x *= factor; this.y *= factor;
        return this;
    },
    
    /*
       Method: $div
    
       Returns the division of two <Complex> numbers.
       
       Alters the original object.

       Parameters:
    
          pos - A <Complex> number.
    
       Returns:
    
         The result of scaling this complex to a factor.
    */
    $div: function(pos) {
        var x = this.x, y = this.y;
        var sq = pos.squaredNorm();
        this.x = x * pos.x + y * pos.y; this.y = y * pos.x - x * pos.y;
        return this.$scale(1 / sq);
    }
};

var $C = function(a, b) { return new Complex(a, b); };

Complex.KER = $C(0, 0);



/*
 * File: Graph.js
 *
 * Generic <Graph>, <Graph.Node> and <Graph.Adjacence> classes.
 *
 * Used by:
 *
 * <Hypertree>, <RGraph> and <ST>.
 *
*/

/*
 Class: Graph

 A generic Graph class.

 Description:

 When a json graph/tree structure is loaded by <Loader.loadJSON>, an internal <Graph> representation is created. 

 In most cases you'll be dealing with an already created <Graph> structure, so methods like <Graph.addNode> or <Graph.addAdjacence> won't 
 be of many use. However methods like <Graph.getNode> and <Graph.hasNode> are pretty useful.

 <Graph.Util> provides also iterators for <Graphs> and advanced and useful graph operations and methods.

 Used by:

 <Loader.loadJSON>, <Hypertree>, <RGraph> and <ST>.

 Access:

 An instance of this class can be accessed by using the _graph_ parameter of a <Hypertree>, <RGraph> or <ST> instance

 Example:

 (start code js)
   var st = new ST(canvas, config);
   st.graph.getNode //or any other <Graph> method.
   
   var ht = new Hypertree(canvas, config);
   ht.graph.getNode //or any other <Graph> method.
   
   var rg = new RGraph(canvas, config);
   rg.graph.getNode //or any other <Graph> method.
 (end code)
 
*/  

this.Graph = new Class({

 initialize: function(opt) {
    var innerOptions = {
		'complex': false,
		'Node': {}
	};
    this.opt = $merge(innerOptions, opt || {});
    this.nodes= {};
 },

/*
     Method: getNode
    
     Returns a <Graph.Node> by _id_.

     Parameters:

     id - A <Graph.Node> id.

     Returns:

     A <Graph.Node> having _id_ as id. Returns *false* otherwise.

     Example:

     (start code js)
       var node = graph.getNode('someid');
     (end code)
*/  
 getNode: function(id) {
    if(this.hasNode(id)) return this.nodes[id];
    return false;
 },

/*
     Method: getAdjacence
    
     Returns an array of <Graph.Adjacence> objects connecting nodes with ids _id_ and _id2_.

     Parameters:

     id - A <Graph.Node> id.
     id2 - A <Graph.Node> id.

     Returns:

     An Array of <Graph.Adjacence> objects. Returns *false* if there's not a <Graph.Adjacence> connecting those two nodes.
*/  
  getAdjacence: function (id, id2) {
    var adjs = [];
    if(this.hasNode(id)     && this.hasNode(id2) 
    && this.nodes[id].adjacentTo({ 'id':id2 }) && this.nodes[id2].adjacentTo({ 'id':id })) {
        adjs.push(this.nodes[id].getAdjacency(id2));
        adjs.push(this.nodes[id2].getAdjacency(id));
        return adjs;
    }
    return false;   
 },

    /*
     Method: addNode
    
     Adds a node.
     
     Parameters:
    
        obj - An object containing as properties

        - _id_ node's id
        - _name_ node's name
        - _data_ node's data hash

    See also:
    <Graph.Node>

  */  
  addNode: function(obj) {
    if(!this.nodes[obj.id]) {
        this.nodes[obj.id] = new Graph.Node($extend({
			'id': obj.id,
			'name': obj.name,
			'data': obj.data
		}, this.opt.Node), this.opt.complex);
    }
    return this.nodes[obj.id];
  },
  
    /*
     Method: addAdjacence
    
     Connects nodes specified by _obj_ and _obj2_. If not found, nodes are created.
     
     Parameters:
    
        obj - a <Graph.Node> object.
        obj2 - Another <Graph.Node> object.
        data - A DataSet object. Used to store some extra information in the <Graph.Adjacence> object created.

    See also:

    <Graph.Node>, <Graph.Adjacence>
    */  
  addAdjacence: function (obj, obj2, data) {
    var adjs = []
    if(!this.hasNode(obj.id)) this.addNode(obj);
    if(!this.hasNode(obj2.id)) this.addNode(obj2);
    obj = this.nodes[obj.id]; obj2 = this.nodes[obj2.id];
    
    for(var i in this.nodes) {
        if(this.nodes[i].id == obj.id) {
            if(!this.nodes[i].adjacentTo(obj2)) {
                adjs.push(this.nodes[i].addAdjacency(obj2, data));
            }
        }
        
        if(this.nodes[i].id == obj2.id) {   
            if(!this.nodes[i].adjacentTo(obj)) {
                adjs.push(this.nodes[i].addAdjacency(obj, data));
            }
        }
    }
    return adjs;
 },

    /*
     Method: removeNode
    
     Removes a <Graph.Node> matching the specified _id_.

     Parameters:

     id - A node's id.

    */  
  removeNode: function(id) {
    if(this.hasNode(id)) {
        var node = this.nodes[id];
        for(var i=0 in node.adjacencies) {
            var adj = node.adjacencies[i];
            this.removeAdjacence(id, adj.nodeTo.id);
        }
        delete this.nodes[id];
    }
  },
  
/*
     Method: removeAdjacence
    
     Removes a <Graph.Adjacence> matching _id1_ and _id2_.

     Parameters:

     id1 - A <Graph.Node> id.
     id2 - A <Graph.Node> id.
*/  
  removeAdjacence: function(id1, id2) {
    if(this.hasNode(id1)) this.nodes[id1].removeAdjacency(id2);
    if(this.hasNode(id2)) this.nodes[id2].removeAdjacency(id1);
  },

    /*
     Method: hasNode
    
     Returns a Boolean instance indicating if the node belongs to the <Graph> or not.
     
     Parameters:
    
        id - Node id.

     Returns:
      
     A Boolean instance indicating if the node belongs to the graph or not.
    */  
  hasNode: function(id) {
    return id in this.nodes;
  }
});

/*
     Class: Graph.Node

     A <Graph> node.

     Parameters:

     obj - An object containing an 'id', 'name' and 'data' properties as described in <Graph.addNode>.
     complex - Whether node position properties should contain <Complex> or <Polar> instances.

     See also:

     <Graph>

     Description:

     An instance of <Graph.Node> is usually passed as parameter for most configuration/controller methods in the 
     <Hypertree>, <RGraph> and <ST> classes.

     A <Graph.Node> object has as properties

      id - Node id.
      name - Node name.
      data - Node data property containing a hash (i.e {}) with custom options. For more information see <Loader.loadJSON>.
      selected - Whether the node is selected or not. Used by <ST> for selecting nodes that are between the root node and the selected node.
      angleSpan - For radial layouts such as the ones performed by the <Hypertree> and the <RGraph>. Contains _begin_ and _end_ properties containing angle values describing the angle span for this subtree.
      alpha - Current opacity value.
      startAlpha - Opacity begin value. Used for interpolation.
      endAlpha - Opacity end value. Used for interpolation.
      pos - Current position. Can be a <Complex> or <Polar> instance.
      startPos - Starting position. Used for interpolation.
      endPos - Ending position. Used for interpolation.
*/
Graph.Node = new Class({
    
    initialize: function(opt, complex) {
		var innerOptions = {
			'id': '',
			'name': '',
			'data': {},
			'adjacencies': {},

			'selected': false,
			'drawn': false,
			'exist': false,

			'angleSpan': {
				'begin': 0,
				'end' : 0
			},

			'alpha': 1,
			'startAlpha': 1,
			'endAlpha': 1,
			
			'pos': (complex && $C(0, 0)) || $P(0, 0),
			'startPos': (complex && $C(0, 0)) || $P(0, 0),
			'endPos': (complex && $C(0, 0)) || $P(0, 0)
		};
		
		$extend(this, $extend(innerOptions, opt));
	},

    /*
       Method: adjacentTo
    
       Indicates if the node is adjacent to the node specified by id

       Parameters:
    
          id - A node id.
    
       Returns:
    
         A Boolean instance indicating whether this node is adjacent to the specified by id or not.

       Example:
       (start code js)
        node.adjacentTo('mynodeid');
       (end code)
    */
    adjacentTo: function(node) {
        return node.id in this.adjacencies;
    },

    /*
       Method: getAdjacency
    
       Returns a <Graph.Adjacence> object connecting the current <Graph.Node> and the node having _id_ as id.

       Parameters:
    
          id - A node id.

       Returns:

          A <Graph.Adjacence> object or undefined.
    */  
    getAdjacency: function(id) {
        return this.adjacencies[id];
    },
    /*
       Method: addAdjacency
    
       Connects the current node and the given node.

       Parameters:
    
          node - A <Graph.Node>.
          data - Some custom hash information.
    */  
    addAdjacency: function(node, data) {
        var adj = new Graph.Adjacence(this, node, data);
        return this.adjacencies[node.id] = adj;
    },
    
    /*
       Method: removeAdjacency
    
       Removes a <Graph.Adjacence> by _id_.

       Parameters:
    
          id - A node id.
    */  
    removeAdjacency: function(id) {
        delete this.adjacencies[id];
    }
});

/*
     Class: Graph.Adjacence

     A <Graph> adjacence (or edge). Connects two <Graph.Nodes>.

     Parameters:

     nodeFrom - A <Graph.Node>.
     nodeTo - A <Graph.Node>.
     data - Some custom hash data.

     See also:

     <Graph>

     Description:

     An instance of <Graph.Adjacence> is usually passed as parameter for some configuration/controller methods in the 
     <Hypertree>, <RGraph> and <ST> classes.

     A <Graph.Adjacence> object has as properties

      nodeFrom - A <Graph.Node> connected by this edge.
      nodeTo - Another  <Graph.Node> connected by this edge.
      data - Node data property containing a hash (i.e {}) with custom options. For more information see <Loader.loadJSON>.
      alpha - Current opacity value.
      startAlpha - Opacity begin value. Used for interpolation.
      endAlpha - Opacity end value. Used for interpolation.
*/
Graph.Adjacence = function(nodeFrom, nodeTo, data) {
    this.nodeFrom = nodeFrom;
    this.nodeTo = nodeTo;
    this.data = data || {};
    this.alpha = 1;
    this.startAlpha = 1;
    this.endAlpha = 1;
};

/*
   Object: Graph.Util

   <Graph> traversal and processing utility object.
*/
Graph.Util = {
    /*
       filter
    
       For internal use only. Provides a filtering function based on flags.
    */
    filter: function(param) {
        if(!param || !($type(param) == 'string')) return function() { return true; };
        var props = param.split(" ");
        return function(elem) {
            for(var i=0; i<props.length; i++) if(elem[props[i]]) return false;
            return true;
        };
    },
    /*
       Method: getNode
    
       Returns a <Graph.Node> by _id_.

       Parameters:

       graph - A <Graph> instance.
       id - A <Graph.Node> id.

       Returns:

       A <Graph> node.

       Example:

       (start code js)
         Graph.Util.getNode(graph, 'nodeid');
       (end code)
    */
    getNode: function(graph, id) {
        return graph.getNode(id);
    },
    
    /*
       Method: eachNode
    
       Iterates over <Graph> nodes performing an _action_.

       Parameters:

       graph - A <Graph> instance.
       action - A callback function having a <Graph.Node> as first formal parameter.

       Example:
       (start code js)
         Graph.Util.each(graph, function(node) {
          alert(node.name);
         });
       (end code)
    */
    eachNode: function(graph, action, flags) {
        var filter = this.filter(flags);
        for(var i in graph.nodes) if(filter(graph.nodes[i])) action(graph.nodes[i]);
    },
    
    /*
       Method: eachAdjacency
    
       Iterates over <Graph.Node> adjacencies applying the _action_ function.

       Parameters:

       node - A <Graph.Node>.
       action - A callback function having <Graph.Adjacence> as first formal parameter.

       Example:
       (start code js)
         Graph.Util.eachAdjacency(node, function(adj) {
          alert(adj.nodeTo.name);
         });
       (end code)
    */
    eachAdjacency: function(node, action, flags) {
        var adj = node.adjacencies, filter = this.filter(flags);
        for(var id in adj) if(filter(adj[id])) action(adj[id], id);
    },

     /*
       Method: computeLevels
    
       Performs a BFS traversal setting the correct depth for each node.

       The depth of each node can then be accessed by 
       >node._depth

       Parameters:

       graph - A <Graph>.
       id - A starting node id for the BFS traversal.
       startDepth - _optional_ A minimum depth value. Default's 0.

    */
    computeLevels: function(graph, id, startDepth, flags) {
        startDepth = startDepth || 0;
        var filter = this.filter(flags);
        this.eachNode(graph, function(elem) {
            elem._flag = false;
            elem._depth = -1;
        }, flags);
		var root = graph.getNode(id);
        root._depth = startDepth;
        var queue = [root];
        while(queue.length != 0) {
            var node = queue.pop();
            node._flag = true;
            this.eachAdjacency(node, function(adj) {
                var n = adj.nodeTo;
                if(n._flag == false && filter(n)) {
                    if(n._depth < 0) n._depth = node._depth + 1 + startDepth;
                    queue.unshift(n);
                }
            }, flags);
        }
    },

    /*
       Method: eachBFS
    
       Performs a BFS traversal applying _action_ to each <Graph.Node>.

       Parameters:

       graph - A <Graph>.
       id - A starting node id for the BFS traversal.
       action - A callback function having a <Graph.Node> as first formal parameter.

       Example:
       (start code js)
         Graph.Util.eachBFS(graph, 'mynodeid', function(node) {
          alert(node.name);
         });
       (end code)
    */
    eachBFS: function(graph, id, action, flags) {
        var filter = this.filter(flags);
        this.clean(graph);
        var queue = [graph.getNode(id)];
        while(queue.length != 0) {
            var node = queue.pop();
            node._flag = true;
            action(node, node._depth);
            this.eachAdjacency(node, function(adj) {
                var n = adj.nodeTo;
                if(n._flag == false && filter(n)) {
                    n._flag = true;
                    queue.unshift(n);
                }
            }, flags);
        }
    },
    
    /*
       Method: eachLevel
    
       Iterates over a node's subgraph applying _action_ to the nodes of relative depth between _levelBegin_ and _levelEnd_.

       Parameters:
       
       node - A <Graph.Node>.
       levelBegin - A relative level value.
       levelEnd - A relative level value.
       action - A callback function having a <Graph.Node> as first formal parameter.

    */
    eachLevel: function(node, levelBegin, levelEnd, action, flags) {
        var d = node._depth, filter = this.filter(flags), that = this;
		levelEnd = levelEnd === false? Number.MAX_VALUE -d : levelEnd;
        (function loopLevel(node, levelBegin, levelEnd) {
            var d = node._depth;
            if(d >= levelBegin && d <= levelEnd && filter(node)) action(node, d);
            if(d < levelEnd) {
                that.eachAdjacency(node, function(adj) {
                    var n = adj.nodeTo;
                    if(n._depth > d) loopLevel(n, levelBegin, levelEnd);
                });
            }
        })(node, levelBegin + d, levelEnd + d);      
    },

    /*
       Method: eachSubgraph
    
       Iterates over a node's children recursively.

       Parameters:
       node - A <Graph.Node>.
       action - A callback function having a <Graph.Node> as first formal parameter.

       Example:
       (start code js)
         Graph.Util.eachSubgraph(node, function(node) {
          alert(node.name);
         });
       (end code)
    */
    eachSubgraph: function(node, action, flags) {
		this.eachLevel(node, 0, false, action, flags);
    },

    /*
       Method: eachSubnode
    
       Iterates over a node's children (without deeper recursion).
       
       Parameters:
       node - A <Graph.Node>.
       action - A callback function having a <Graph.Node> as first formal parameter.

       Example:
       (start code js)
         Graph.Util.eachSubnode(node, function(node) {
          alert(node.name);
         });
       (end code)
    */
    eachSubnode: function(node, action, flags) {
        this.eachLevel(node, 1, 1, action, flags);
    },

    /*
       Method: anySubnode
    
       Returns *true* if any subnode matches the given condition.

       Parameters:
       node - A <Graph.Node>.
       cond - A callback function returning a Boolean instance. This function has as first formal parameter a <Graph.Node>.

       Returns:
       A boolean value.

       Example:
       (start code js)
         Graph.Util.anySubnode(node, function(node) { return node.name == "mynodename"; });
       (end code)
    */
    anySubnode: function(node, cond, flags) {
        var flag = false;
		cond = cond || $lambda(true);
		var c = $type(cond) == 'string'? function(n) { return n[cond]; } : cond;
		this.eachSubnode(node, function(elem) {
			if(c(elem)) flag = true;
		}, flags);
		return flag;
    },
	
    /*
       Method: getSubnodes
    
       Collects all subnodes for a specified node. The _level_ parameter filters nodes having relative depth of _level_ from the root node.

       Parameters:
       node - A <Graph.Node>.
       level - _optional_ A starting relative depth for collecting nodes. Default's 0.

       Returns:
       An array of nodes.

    */
    getSubnodes: function(node, level, flags) {
        var ans = [], that = this;
        level = level || 0;
        if($type(level) == 'array') {
            var levelStart = level[0];
            var levelEnd = level[1];
        } else {
            var levelStart = level;
            var levelEnd = Number.MAX_VALUE - node._depth;
        }
        this.eachLevel(node, levelStart, levelEnd, function(n) {
			ans.push(n);
		}, flags);
        return ans;
    },
	
	
    /*
       Method: getParents
    
       Returns an Array of <Graph.Nodes> wich are parents of the given node. 

       Parameters:
       node - A <Graph.Node>.

       Returns:
       An Array of <Graph.Nodes>.

       Example:
       (start code js)
         var pars = Graph.Util.getParents(node);
         if(pars.length > 0) {
           //do stuff with parents
         }
       (end code)
    */
    getParents: function(node) {
        var ans = [];
        this.eachAdjacency(node, function(adj) {
            var n = adj.nodeTo;
            if(n._depth < node._depth) ans.push(n);
        });
        return ans;
    },
    
    /*
       Method: clean
    
       Cleans flags from nodes (by setting the _flag_ property to false).

       Parameters:
       graph - A <Graph> instance.
    */
    clean: function(graph) { this.eachNode(graph, function(elem) { elem._flag = false; }); }
};



/*
 * File: Graph.Op.js
 *
 * Defines an abstract class for performing <Graph> Operations.
*/

/*
   Object: Graph.Op

   Generic <Graph> Operations.
   
   Description:

   An abstract class holding unary and binary powerful graph operations such as removingNodes, removingEdges, adding two graphs and morphing.

   Implemented by:

   <Hypertree.Op>, <RGraph.Op> and <ST.Op>.

   Access:

   The subclasses for this abstract class can be accessed by using the _op_ property of the <Hypertree>, <RGraph> or <ST> instances created.

   See also:

   <Hypertree.Op>, <RGraph.Op>, <ST.Op>, <Hypertree>, <RGraph>, <ST>, <Graph>.
*/
Graph.Op = {

    options: {
        type: 'nothing',
        duration: 2000,
		hideLabels: true,
        fps:30
    },
	
    /*
       Method: removeNode
    
       Removes one or more <Graph.Nodes> from the visualization. 
       It can also perform several animations like fading sequentially, fading concurrently, iterating or replotting.

       Parameters:
    
          node - The node's id. Can also be an array having many ids.
          opt - Animation options. It's an object with optional properties
          
          - _type_ Type of the animation. Can be "nothing", "replot", "fade:seq",  "fade:con" or "iter". Default's "nothing".
          - _duration_ Duration of the animation in milliseconds. Default's 2000.
          - _fps_ Frames per second for the animation. Default's 30.
          - _hideLabels_ Hide labels during the animation. Default's *true*.
          - _transition_ Transitions defined in the <Animation> class. Default's the default transition option of the 
          <RGraph>, <Hypertree> or <ST> instance created.
   
      Example:
      (start code js)
        var rg = new RGraph(canvas, config); //could be new ST or new Hypertree also.
        rg.op.removeNode('nodeid', {
          type: 'fade:seq',
          duration: 1000,
          hideLabels: false,
          transition: Trans.Quart.easeOut
        });
        //or also
        rg.op.removeNode(['someid', 'otherid'], {
          type: 'fade:con',
          duration: 1500
        });
      (end code)
    */
	
    removeNode: function(node, opt) {
        var viz = this.viz;
		var options = $merge(this.options, viz.controller, opt);
        var n = $splat(node);
        switch(options.type) {
            case 'nothing':
                for(var i=0; i<n.length; i++) viz.graph.removeNode(n[i]);
                break;
            
            case 'replot':
                this.removeNode(n, { type: 'nothing' });
                viz.fx.clearLabels();
                viz.refresh(true);
                break;
            
            case 'fade:seq': case 'fade':
                var that = this;
                //set alpha to 0 for nodes to remove.
                for(var i=0; i<n.length; i++) {
                    var nodeObj = viz.graph.getNode(n[i]);
                    nodeObj.endAlpha = 0;
                }
                viz.fx.animate($merge(options, {
                    modes: ['fade:nodes'],
                    onComplete: function() {
                        that.removeNode(n, { type: 'nothing' });
                        viz.fx.clearLabels();
                        viz.reposition();
                        viz.fx.animate($merge(options, {
                            modes: ['linear']
                        }));
                    }
                }));
                break;
            
            case 'fade:con':
                var that = this;
                //set alpha to 0 for nodes to remove. Tag them for being ignored on computing positions.
                for(var i=0; i<n.length; i++) {
                    var nodeObj = viz.graph.getNode(n[i]);
                    nodeObj.endAlpha = 0;
                    nodeObj.ignore = true;
                }
                viz.reposition();
                viz.fx.animate($merge(options, {
                    modes: ['fade:nodes', 'linear'],
                    onComplete: function() {
                        that.removeNode(n, { type: 'nothing' });
                    }
                }));
                break;
            
            case 'iter':
                var that = this;
                viz.fx.sequence({
                    condition: function() { return n.length != 0; },
                    step: function() { that.removeNode(n.shift(), { type: 'nothing' });  viz.fx.clearLabels(); },
                    onComplete: function() { options.onComplete(); },
                    duration: Math.ceil(options.duration / n.length)
                });
                break;
                
            default: this.doError();
        }
    },
    
    /*
       Method: removeEdge
    
       Removes one or more edges from the visualization. 
       It can also perform several animations like fading sequentially, fading concurrently, iterating or replotting.

       Parameters:
    
       vertex - An array having two strings which are the ids of the nodes connected by this edge (i.e ['id1', 'id2']). Can also be a two dimensional array holding many edges (i.e [['id1', 'id2'], ['id3', 'id4'], ...]).
          opt - Animation options. It's an object with optional properties
          
          - _type_ Type of the animation. Can be "nothing", "replot", "fade:seq",  "fade:con" or "iter". Default's "nothing".
          - _duration_ Duration of the animation in milliseconds. Default's 2000.
          - _fps_ Frames per second for the animation. Default's 30.
          - _hideLabels_ Hide labels during the animation. Default's *true*.
          - _transition_ Transitions defined in the <Animation> class. Default's the default transition option of the 
          <RGraph>, <Hypertree> or <ST> instance created.
   
      Example:
      (start code js)
        var rg = new RGraph(canvas, config); //could be new ST or new Hypertree also.
        rg.op.removeEdge(['nodeid', 'otherid'], {
          type: 'fade:seq',
          duration: 1000,
          hideLabels: false,
          transition: Trans.Quart.easeOut
        });
        //or also
        rg.op.removeEdge([['someid', 'otherid'], ['id3', 'id4']], {
          type: 'fade:con',
          duration: 1500
        });
      (end code)
    
    */
    removeEdge: function(vertex, opt) {
        var viz = this.viz;
		var options = $merge(this.options, viz.controller, opt);
        var v = ($type(vertex[0]) == 'string')? [vertex] : vertex;
        switch(options.type) {
            case 'nothing':
                for(var i=0; i<v.length; i++)   viz.graph.removeAdjacence(v[i][0], v[i][1]);
                break;
            
            case 'replot':
                this.removeEdge(v, { type: 'nothing' });
                viz.refresh(true);
                break;
            
            case 'fade:seq': case 'fade':
                var that = this;
                //set alpha to 0 for edges to remove.
                for(var i=0; i<v.length; i++) {
                    var adjs = viz.graph.getAdjacence(v[i][0], v[i][1]);
                    if(adjs) {
                        adjs[0].endAlpha = 0;
                        adjs[1].endAlpha = 0;
                    }
                }
                viz.fx.animate($merge(options, {
                    modes: ['fade:vertex'],
                    onComplete: function() {
                        that.removeEdge(v, { type: 'nothing' });
                        viz.reposition();
                        viz.fx.animate($merge(options, {
                            modes: ['linear']
                        }));
                    }
                }));
                break;
            
            case 'fade:con':
                var that = this;
                //set alpha to 0 for nodes to remove. Tag them for being ignored when computing positions.
                for(var i=0; i<v.length; i++) {
                    var adjs = viz.graph.getAdjacence(v[i][0], v[i][1]);
                    if(adjs) {
                        adjs[0].endAlpha = 0;
                        adjs[0].ignore = true;
                        adjs[1].endAlpha = 0;
                        adjs[1].ignore = true;
                    }
                }
                viz.reposition();
                viz.fx.animate($merge(options, {
                    modes: ['fade:vertex', 'linear'],
                    onComplete: function() {
                        that.removeEdge(v, { type: 'nothing' });
                    }
                }));
                break;
            
            case 'iter':
                var that = this;
                viz.fx.sequence({
                    condition: function() { return v.length != 0; },
                    step: function() { that.removeEdge(v.shift(), { type: 'nothing' }); viz.fx.clearLabels(); },
                    onComplete: function() { options.onComplete(); },
                    duration: Math.ceil(options.duration / v.length)
                });
                break;
                
            default: this.doError();
        }
    },
    
    /*
       Method: sum
    
       Adds a new graph to the visualization. 
       
       The json graph (or tree) must at least have a common node with the current graph plotted by the visualization. 
       
       The resulting graph can be defined as follows <http://mathworld.wolfram.com/GraphSum.html>

       Parameters:
    
          json - A json tree or graph structure. See also <Loader.loadJSON>.
           opt - Animation options. It's an object with optional properties
          
          - _type_ Type of the animation. Can be "nothing", "replot", "fade:seq" or "fade:con". Default's "nothing".
          - _duration_ Duration of the animation in milliseconds. Default's 2000.
          - _fps_ Frames per second for the animation. Default's 30.
          - _hideLabels_ Hide labels during the animation. Default's *true*.
          - _transition_ Transitions defined in the <Animation> class. Default's the default transition option of the 
          <RGraph>, <Hypertree> or <ST> instance created.
   
      Example:
      (start code js)
        //json contains a tree or graph structure.

        var rg = new RGraph(canvas, config); //could be new ST or new Hypertree also.
        rg.op.sum(json, {
          type: 'fade:seq',
          duration: 1000,
          hideLabels: false,
          transition: Trans.Quart.easeOut
        });
        //or also
        rg.op.sum(json, {
          type: 'fade:con',
          duration: 1500
        });
      (end code)
    
    */
    sum: function(json, opt) {
		var viz = this.viz;
        var options = $merge(this.options, viz.controller, opt), root = viz.root;
        viz.root = opt.id || viz.root;
        switch(options.type) {
            case 'nothing':
                var graph = viz.construct(json), GUtil = Graph.Util;
                GUtil.eachNode(graph, function(elem) {
                    GUtil.eachAdjacency(elem, function(adj) {
                        viz.graph.addAdjacence(adj.nodeFrom, adj.nodeTo, adj.data);
                    });
                });
                break;
            
            case 'replot':
                viz.refresh(true);
                this.sum(json, { type: 'nothing' });
                viz.refresh(true);
                break;
            
            case 'fade:seq': case 'fade': case 'fade:con':
                var GUtil = Graph.Util, that = this, graph = viz.construct(json);
                //set alpha to 0 for nodes to add.
                var fadeEdges = this.preprocessSum(graph);
                var modes = !fadeEdges? ['fade:nodes'] : ['fade:nodes', 'fade:vertex'];
                viz.reposition();
                if(options.type != 'fade:con') {
                    viz.fx.animate($merge(options, {
                        modes: ['linear'],
                        onComplete: function() {
                            viz.fx.animate($merge(options, {
                                modes: modes,
                                onComplete: function() {
                                    options.onComplete();
                                }
                            }));
                        }
                    }));
                } else {
                    GUtil.eachNode(viz.graph, function(elem) {
                        if (elem.id != root && elem.pos.getp().equals(Polar.KER)) {
                          elem.pos.set(elem.endPos); elem.startPos.set(elem.endPos);
                        }
                    });
                    viz.fx.animate($merge(options, {
                        modes: ['linear'].concat(modes)
                    }));
                }
                break;

            default: this.doError();
        }
    },
    
    /*
       Method: morph
    
       This method will _morph_ the current visualized graph into the new _json_ representation passed in the method. 
       
       Can also perform multiple animations. The _json_ object must at least have the root node in common with the current visualized graph.

       Parameters:
    
           json - A json tree or graph structure. See also <Loader.loadJSON>.
           opt - Animation options. It's an object with optional properties
          
          - _type_ Type of the animation. Can be "nothing", "replot", or "fade". Default's "nothing".
          - _duration_ Duration of the animation in milliseconds. Default's 2000.
          - _fps_ Frames per second for the animation. Default's 30.
          - _hideLabels_ Hide labels during the animation. Default's *true*.
          - _transition_ Transitions defined in the <Animation> class. Default's the default transition option of the 
          <RGraph>, <Hypertree> or <ST> instance created.
   
      Example:
      (start code js)
        //json contains a tree or graph structure.

        var rg = new RGraph(canvas, config); //could be new ST or new Hypertree also.
        rg.op.morph(json, {
          type: 'fade',
          duration: 1000,
          hideLabels: false,
          transition: Trans.Quart.easeOut
        });
        //or also
        rg.op.morph(json, {
          type: 'fade',
          duration: 1500
        });
      (end code)
    
    */
    morph: function(json, opt) {
        var viz = this.viz;
		var options = $merge(this.options, viz.controller, opt), root = viz.root;
        viz.root = opt.id || viz.root;
        switch(options.type) {
            case 'nothing':
                var graph = viz.construct(json), GUtil = Graph.Util;
                GUtil.eachNode(graph, function(elem) {
                    GUtil.eachAdjacency(elem, function(adj) {
                        viz.graph.addAdjacence(adj.nodeFrom, adj.nodeTo, adj.data);
                    });
                });
                GUtil.eachNode(viz.graph, function(elem) {
                    GUtil.eachAdjacency(elem, function(adj) {
                        if(!graph.getAdjacence(adj.nodeFrom.id, adj.nodeTo.id)) {
                            viz.graph.removeAdjacence(adj.nodeFrom.id, adj.nodeTo.id);
                        }
                    });
                    if(!graph.hasNode(elem.id)) viz.graph.removeNode(elem.id);
                });
                
                break;
            
            case 'replot':
                viz.refresh(true);
                this.morph(json, { type: 'nothing' });
                viz.fx.clearLabels();
                viz.refresh(true);
                break;
            
            case 'fade:seq': case 'fade': case 'fade:con':
                var GUtil = Graph.Util, that = this, graph = viz.construct(json);
                //preprocessing for adding nodes.
                var fadeEdges = this.preprocessSum(graph);
                //preprocessing for nodes to delete.
                GUtil.eachNode(viz.graph, function(elem) {
                    if(!graph.hasNode(elem.id)) {
                        elem.alpha = 1; elem.startAlpha = 1; elem.endAlpha = 0; elem.ignore = true;
                    }
                }); 
                GUtil.eachNode(viz.graph, function(elem) {
                    if(elem.ignore) return;
                    GUtil.eachAdjacency(elem, function(adj) {
                        if(adj.nodeFrom.ignore || adj.nodeTo.ignore) return;
                        var nodeFrom = graph.getNode(adj.nodeFrom.id);
                        var nodeTo = graph.getNode(adj.nodeTo.id);
                        if(!nodeFrom.adjacentTo(nodeTo)) {
                            var adjs = viz.graph.getAdjacence(nodeFrom.id, nodeTo.id);
                            fadeEdges = true;
                            adjs[0].alpha = 1; adjs[0].startAlpha = 1; adjs[0].endAlpha = 0; adjs[0].ignore = true;
                            adjs[1].alpha = 1; adjs[1].startAlpha = 1; adjs[1].endAlpha = 0; adjs[1].ignore = true;
                        }
                    });
                }); 
                var modes = !fadeEdges? ['fade:nodes'] : ['fade:nodes', 'fade:vertex'];
                viz.reposition();
                GUtil.eachNode(viz.graph, function(elem) {
                    if (elem.id != root && elem.pos.getp().equals(Polar.KER)) {
                      elem.pos.set(elem.endPos); elem.startPos.set(elem.endPos);
                    }
                });
                viz.fx.animate($merge(options, {
                    modes: ['polar'].concat(modes),
                    onComplete: function() {
                        GUtil.eachNode(viz.graph, function(elem) {
                            if(elem.ignore) viz.graph.removeNode(elem.id);
                        });
                        GUtil.eachNode(viz.graph, function(elem) {
                            GUtil.eachAdjacency(elem, function(adj) {
                                if(adj.ignore) viz.graph.removeAdjacence(adj.nodeFrom.id, adj.nodeTo.id);
                            });
                        });
                        options.onComplete();
                    }
                }));
                break;

            default: this.doError();
        }
    },
    
    preprocessSum: function(graph) {
        var viz = this.viz;
		var GUtil = Graph.Util;
        GUtil.eachNode(graph, function(elem) {
            if(!viz.graph.hasNode(elem.id)) {
                viz.graph.addNode(elem);
                var n = viz.graph.getNode(elem.id);
                n.alpha = 0; n.startAlpha = 0; n.endAlpha = 1;
            }
        }); 
        var fadeEdges = false;
        GUtil.eachNode(graph, function(elem) {
            GUtil.eachAdjacency(elem, function(adj) {
                var nodeFrom = viz.graph.getNode(adj.nodeFrom.id);
                var nodeTo = viz.graph.getNode(adj.nodeTo.id);
                if(!nodeFrom.adjacentTo(nodeTo)) {
                    var adjs = viz.graph.addAdjacence(nodeFrom, nodeTo, adj.data);
                    if(nodeFrom.startAlpha == nodeFrom.endAlpha 
                    && nodeTo.startAlpha == nodeTo.endAlpha) {
                        fadeEdges = true;
                        adjs[0].alpha = 0; adjs[0].startAlpha = 0; adjs[0].endAlpha = 1;
                        adjs[1].alpha = 0; adjs[1].startAlpha = 0; adjs[1].endAlpha = 1;
                    } 
                }
            });
        }); 
        return fadeEdges;
    }
};



/*
 * File: Graph.Plot.js
 *
 * Defines an abstract class for performing <Graph> rendering and animation.
 *
 */


/*
   Object: Graph.Plot

   Generic <Graph> rendering and animation methods.
   
   Description:

   An abstract class for plotting a generic graph structure.

   Implemented by:

   <Hypertree.Plot>, <RGraph.Plot>, <ST.Plot>.

   Access:

   The subclasses for this abstract class can be accessed by using the _fx_ property of the <Hypertree>, <RGraph>, or <ST> instances created.

   See also:

   <Hypertree.Plot>, <RGraph.Plot>, <ST.Plot>, <Hypertree>, <RGraph>, <ST>, <Graph>.

*/
Graph.Plot = {
    
    Interpolator: {
        'moebius': function(elem, delta, vector) {
            if(delta <= 1 || vector.norm() <= 1) {
				var x = vector.x, y = vector.y;
	            var ans = elem.startPos.getc().moebiusTransformation(vector);
	            elem.pos.setc(ans.x, ans.y);
	            vector.x = x; vector.y = y;
            }           
		},

        'linear': function(elem, delta) {
            var from = elem.startPos.getc(true);
            var to = elem.endPos.getc(true);
            elem.pos.setc((to.x - from.x) * delta + from.x, (to.y - from.y) * delta + from.y);
        },

        'fade:nodes': function(elem, delta) {
            if(delta <= 1 && (elem.endAlpha != elem.alpha)) {
                var from = elem.startAlpha;
                var to   = elem.endAlpha;
                elem.alpha = from + (to - from) * delta;
            }
        },
        
        'fade:vertex': function(elem, delta) {
            var adjs = elem.adjacencies;
            for(var id in adjs) this['fade:nodes'](adjs[id], delta);
        },
        
        'polar': function(elem, delta) {
            var from = elem.startPos.getp(true);
            var to = elem.endPos.getp();
			var ans = to.interpolate(from, delta);
            elem.pos.setp(ans.theta, ans.rho);
        }
    },
    
    //A flag value indicating if node labels are being displayed or not.
    labelsHidden: false,
    //Label DOM element
    labelContainer: false,
    //Label DOM elements hash.
    labels: {},

    /*
       Method: getLabelContainer
    
       Lazy fetcher for the label container.

       Returns:

       The label container DOM element.

       Example:

      (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        var labelContainer = rg.fx.getLabelContainer();
        alert(labelContainer.innerHTML);
      (end code)
    */
    getLabelContainer: function() {
        return this.labelContainer? this.labelContainer : this.labelContainer = document.getElementById(this.viz.config.labelContainer);
    },
    
    /*
       Method: getLabel
    
       Lazy fetcher for the label DOM element.

       Parameters:

       id - The label id (which is also a <Graph.Node> id).

       Returns:

       The label DOM element.

       Example:

      (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        var label = rg.fx.getLabel('someid');
        alert(label.innerHTML);
      (end code)
      
    */
    getLabel: function(id) {
        return (id in this.labels && this.labels[id] != null)? this.labels[id] : this.labels[id] = document.getElementById(id);
    },
    
    /*
       Method: hideLabels
    
       Hides all labels (by hiding the label container).

       Parameters:

       hide - A boolean value indicating if the label container must be hidden or not.

       Example:
       (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        rg.fx.hideLabels(true);
       (end code)
       
    */
    hideLabels: function (hide) {
        var container = this.getLabelContainer();
        if(hide) container.style.display = 'none';
        else container.style.display = '';
        this.labelsHidden = hide;
    },
    
    /*
       Method: clearLabels
    
       Clears the label container.

       Useful when using a new visualization with the same canvas element/widget.

       Example:
       (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        rg.fx.clearLabels();
        (end code)
    */
    clearLabels: function() {
        for(var id in this.labels) 
            if(!this.viz.graph.hasNode(id)) {
                this.disposeLabel(id);
                delete this.labels[id];
            }
    },
    
    /*
       Method: disposeLabel
    
       Removes a label.

       Parameters:

       id - A label id (which generally is also a <Graph.Node> id).

       Example:
       (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        rg.fx.disposeLabel('labelid');
       (end code)
    */
    disposeLabel: function(id) {
        var elem = this.getLabel(id);
        if(elem && elem.parentNode) {
			elem.parentNode.removeChild(elem);
		}  
    },

    /*
       Method: hideLabel
    
       Hides the corresponding <Graph.Node> label.
        
       Parameters:

       node - A <Graph.Node>. Can also be an array of <Graph.Nodes>.
       flag - If *true*, nodes will be shown. Otherwise nodes will be hidden.

       Example:
       (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        rg.fx.hideLabel(rg.graph.getNode('someid'), false);
       (end code)
    */
    hideLabel: function(node, flag) {
		node = $splat(node);
		var st = flag? "" : "none", lab, that = this;
		$each(node, function(n) {
			if(lab = that.getLabel(n.id)) {
			     lab.style.display = st;
			} 
		});
    },

    /*
       Method: sequence
    
       Iteratively performs an action while refreshing the state of the visualization.

       Parameters:

       options - Some sequence options like
      
       - _condition_ A function returning a boolean instance in order to stop iterations.
       - _step_ A function to execute on each step of the iteration.
       - _onComplete_ A function to execute when the sequence finishes.
       - _duration_ Duration (in milliseconds) of each step.

      Example:
       (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        var i = 0;
        rg.fx.sequence({
          condition: function() {
           return i == 10;
          },
          step: function() {
            alert(i++);
          },
          onComplete: function() {
           alert('done!');
          }
        });
       (end code)

    */
    sequence: function(options) {
        var that = this;
		options = $merge({
            condition: $lambda(false),
            step: $empty,
            onComplete: $empty,
            duration: 200
        }, options || {});

        var interval = setInterval(function() {
            if(options.condition()) {
                options.step();
            } else {
                clearInterval(interval);
                options.onComplete();
            }
            that.viz.refresh(true);
        }, options.duration);
    },
    
    /*
       Method: animate
    
       Animates a <Graph> by interpolating some <Graph.Nodes> properties.

       Parameters:

       opt - Animation options. This object contains as properties

       - _modes_ (required) An Array of animation types. Possible values are "linear", "polar", "moebius", "fade:nodes" and "fade:vertex".

       "linear", "polar" and "moebius" animation options will interpolate <Graph.Nodes> "startPos" and "endPos" properties, storing the result in "pos".
       
       "fade:nodes" and "fade:vertex" animation options will interpolate <Graph.Nodes> and/or <Graph.Adjacence> "startAlpha" and "endAlpha" properties, storing the result in "alpha".

       - _duration_ Duration (in milliseconds) of the Animation.
       - _fps_ Frames per second.
       - _hideLabels_ hide labels or not during the animation.

       ...and other <Hypertree>, <RGraph> or <ST> controller methods.

       Example:
       (start code js)
        var rg = new RGraph(canvas, config); //can be also Hypertree or ST
        rg.fx.animate({
          modes: ['linear'],
          hideLabels: false
        }); 
       (end code)
       
       
    */
    animate: function(opt, versor) {
        var that = this,
		viz = this.viz,
		graph  = viz.graph,
		GUtil = Graph.Util;
		opt = $merge(viz.controller, opt || {}); 
		
        if(opt.hideLabels) this.hideLabels(true);
        this.animation.setOptions($merge(opt, {
            $animating: false,
            compute: function(delta) {
				var vector = versor? versor.scale(-delta) : null;
				GUtil.eachNode(graph, function(node) { 
                    for(var i=0; i<opt.modes.length; i++) {
						that.Interpolator[opt.modes[i]](node, delta, vector);
					} 
                });
                that.plot(opt, this.$animating);
                this.$animating = true;
            },
            complete: function() {
                GUtil.eachNode(graph, function(node) { 
                    node.startPos.set(node.pos);
                    node.startAlpha = node.alpha;
                });
                if(opt.hideLabels) that.hideLabels(false);
                that.plot(opt);
                opt.onComplete();
                opt.onAfterCompute();
            }       
		})).start();
    },
    
    /*
       Method: plot
    
       Plots a <Graph>.

       Parameters:

       opt - _optional_ Plotting options.

       Example:

       (start code js)
       var rg = new RGraph(canvas, config); //can be also Hypertree or ST
       rg.fx.plot(); 
       (end code)

    */
    plot: function(opt, animating) {
        var viz = this.viz, 
		aGraph = viz.graph, 
		canvas = viz.canvas, 
		id = viz.root, 
		that = this, 
		ctx = canvas.getCtx(), 
		GUtil = Graph.Util;
        opt = opt || this.viz.controller;
		opt.clearCanvas && canvas.clear();
        
        var T = !!aGraph.getNode(id).visited;
        GUtil.eachNode(aGraph, function(node) {
            GUtil.eachAdjacency(node, function(adj) {
				var nodeTo = adj.nodeTo;
                if(!!nodeTo.visited === T && node.drawn && nodeTo.drawn) {
                    !animating && opt.onBeforePlotLine(adj);
                    ctx.save();
                    ctx.globalAlpha = Math.min(Math.min(node.alpha, nodeTo.alpha), adj.alpha);
                    that.plotLine(adj, canvas, animating);
                    ctx.restore();
                    !animating && opt.onAfterPlotLine(adj);
                }
            });
            ctx.save();
			if(node.drawn) {
	            ctx.globalAlpha = node.alpha;
	            !animating && opt.onBeforePlotNode(node);
	            that.plotNode(node, canvas, animating);
	            !animating && opt.onAfterPlotNode(node);
			}
            if(!that.labelsHidden && opt.withLabels) {
				if(node.drawn && ctx.globalAlpha >= .95) {
					that.plotLabel(canvas, node, opt);
				} else {
					that.hideLabel(node, false);
				}
			}
            ctx.restore();
            node.visited = !T;
        });
    },

    /*
       Method: plotLabel
    
       Plots a label for a given node.

       Parameters:

       canvas - A <Canvas> instance.
       node - A <Graph.Node>.
       controller - A configuration object. See also <Hypertree>, <RGraph>, <ST>.

    */
    plotLabel: function(canvas, node, controller) {
		var id = node.id, tag = this.getLabel(id);
        if(!tag && !(tag = document.getElementById(id))) {
            tag = document.createElement('div');
            var container = this.getLabelContainer();
            container.appendChild(tag);
            tag.id = id;
            tag.className = 'node';
            tag.style.position = 'absolute';
            controller.onCreateLabel(tag, node);
            this.labels[node.id] = tag;
        }
		this.placeLabel(tag, node, controller);
    },
	
	/*
       Method: plotNode
    
       Plots a <Graph.Node>.

       Parameters:
       
       node - A <Graph.Node>.
       canvas - A <Canvas> element.

    */
    plotNode: function(node, canvas, animating) {
        var nconfig = this.node, data = node.data;
        var cond = nconfig.overridable && data;
        var width = cond && data.$lineWidth || nconfig.lineWidth;
        var color = cond && data.$color || nconfig.color;
        var ctx = canvas.getCtx();
        
        ctx.lineWidth = width;
		ctx.fillStyle = color;
		ctx.strokeStyle = color; 

        var f = node.data && node.data.$type || nconfig.type;
        this.nodeTypes[f].call(this, node, canvas, animating);
    },
    
    /*
       Method: plotLine
    
       Plots a line.

       Parameters:

       adj - A <Graph.Adjacence>.
       canvas - A <Canvas> instance.

    */
    plotLine: function(adj, canvas, animating) {
        var econfig = this.edge, data = adj.data;
        var cond = econfig.overridable && data;
        var width = cond && data.$lineWidth || econfig.lineWidth;
        var color = cond && data.$color || econfig.color;
        var ctx = canvas.getCtx();
        
        ctx.lineWidth = width;
        ctx.fillStyle = color;
        ctx.strokeStyle = color; 

        var f = adj.data && adj.data.$type || econfig.type;
        this.edgeTypes[f].call(this, adj, canvas, animating);
    },    
	
	/*
       Method: fitsInCanvas
    
       Returns _true_ or _false_ if the label for the node is contained in the canvas dom element or not.

       Parameters:

       pos - A <Complex> instance (I'm doing duck typing here so any object with _x_ and _y_ parameters will do).
       canvas - A <Canvas> instance.
       
       Returns:

       A boolean value specifying if the label is contained in the <Canvas> DOM element or not.

    */
    fitsInCanvas: function(pos, canvas) {
        var size = canvas.getSize();
        if(pos.x >= size.width || pos.x < 0 
            || pos.y >= size.height || pos.y < 0) return false;
        return true;                    
    }
};


/*
 * File: Loader.js
 * 
 * Provides methods for loading JSON data.
 *
 * Description:
 *
 * Provides the <Loader.loadJSON> method implemented by the main visualization classes to load JSON Trees and Graphs.
 * 
 * Implemented By: 
 * 
 * <ST>, <TM>, <Hypertree> and <RGraph> classes
 * 
 */

/*
   Object: Loader

   Provides static methods for loading JSON data.

   Description:
   
   This object is extended by the main Visualization classes (<ST>, <Hypertree>, <TM> and <RGraph>)
   in order to implement the <Loader.loadJSON> method. 
   
   The <Loader.loadJSON> method accepts JSON Trees and Graph objects. This will be explained in detail in the <Loader.loadJSON> method definition.
*/
var Loader = {
	   construct: function(json) {
        var isGraph = ($type(json) == 'array');
        var ans = new Graph(this.graphOptions);
        if(!isGraph) 
            //make tree
            (function (ans, json) {
                ans.addNode(json);
                for(var i=0, ch = json.children; i<ch.length; i++) {
                    ans.addAdjacence(json, ch[i]);
                    arguments.callee(ans, ch[i]);
                }
            })(ans, json);
        else
            //make graph
            (function (ans, json) {
                var getNode = function(id) {
                    for(var w=0; w<json.length; w++) if(json[w].id == id) return json[w];
                };
                for(var i=0; i<json.length; i++) {
                    ans.addNode(json[i]);
                    for(var j=0, adj = json[i].adjacencies; j<adj.length; j++) {
                        var node = adj[j], data;
                        if(typeof adj[j] != 'string') {
                            data = node.data;
                            node = node.nodeTo;
                        }
                        ans.addAdjacence(json[i], getNode(node), data);
                    }
                }
            })(ans, json);

        return ans;
    },

    /*
     Method: loadJSON
    
     Loads a JSON structure to the visualization. The JSON structure can be a JSON tree or graph structure.
     
        A JSON tree or graph structure consists of nodes, each having as properties
       - _id_ A unique identifier for the node
       - _name_ A node's name
       - _data_ The data property contains a hash (i.e {}) where you can store all 
       the information you want about this node.
        
        Hash keys prefixed with a dollar sign (i.e $) have special meaning. I will detail those properties below.
      
        For JSON tree structures, there's an extra property _children_ of type Array which contains the node's children.
      
      Example:

      (start code js)
        var json = {  
            "id": "aUniqueIdentifier",  
            "name": "usually a nodes name",  
            "data": {
                "some key": "some value",
                "some other key": "some other value"
             },  
            "children": [ 'other nodes or empty' ]  
        };  
      (end code)
        
        JSON Graph structures consist of an array of nodes, each specifying the nodes to which the current node is connected.
        
        For JSON Graph structures, the _children_ property is replaced by the _adjacencies_ property.
        
        There are two types of Graph structures, _simple_ and _extended_ graph structures.
        
        For _simple_ Graph structures, the adjacencies property contains an array of strings, each specifying the 
        id of the node connected to the main node.
        
        Example:
        
        (start code js)
        var json = [  
            {  
                "id": "aUniqueIdentifier",  
                "name": "usually a nodes name",  
                "data": {
                    "some key": "some value",
                    "some other key": "some other value"
                 },  
                "adjacencies": ["anotherUniqueIdentifier", "yetAnotherUniqueIdentifier", 'etc']  
            },

            'other nodes go here...' 
        ];          
        (end code)
        
        For _extended_ Graph structures, the adjacencies property contains an array of Adjacency objects that have as properties
        - nodeTo The other node connected by this adjacency.
        - data A data property, where we can store custom key/value information.
        
        Example:
        
        (start code js)
        var json = [  
            {  
                "id": "aUniqueIdentifier",  
                "name": "usually a nodes name",  
                "data": {
                    "some key": "some value",
                    "some other key": "some other value"
                 },  
                "adjacencies": [  
                {  
                    nodeTo:"aNodeId",  
                    data: {} //put whatever you want here  
                },
                'other adjacencies go here...'  
            },

            'other nodes go here...' 
        ];          
        (end code)
        
        Since all visualizations implement this method, this will be the entry point for JSON data for all visualizations. This method could be called like this
        
        Example:
        
        (start code js)
        var ht = new Hypertree(canvas, config);
        ht.loadJSON(json);
        
        var tm = new TM.Squarified(config);
        tm.loadJSON(json);
        
        var st = new ST(canvas, config);
        st.loadJSON(json);
        
        var rg = new RGraph(canvas, config);
        rg.loadJSON(json);
        
        (end code)
        
       Parameters:
    
          json - A JSON Tree or Graph structure.
          i - For Graph structures only. Sets the indexed node as root for the visualization.

    */
    loadJSON: function(json, i) {
		this.json = json;
		this.graph = this.construct(json);
		if($type(json) != 'array'){
			this.root = json.id;
		} else {
			this.root = json[i? i : 0].id;
		}
	}
};



/*
 * File: Animation.js
 * 
 * Core <Animation> and <Trans> transition classes.
 *
*/

/*
   Object: Trans
    
     An object containing multiple type of transformations. 
     
     Based on:
         
     MooTools library <http://mootools.net>.

     Used by:

     <RGraph>, <Hypertree> and <ST> classes.

     Description:

     This object is used for specifying different animation transitions in the <RGraph>, <Hypertree> and <ST> classes.

     There are many different type of animation transitions.

     linear:

     Displays a linear transition

     >Trans.linear
     
     (see Linear.png)

     Quad:

     Displays a Quadratic transition.
  
     >Trans.Quad.easeIn
     >Trans.Quad.easeOut
     >Trans.Quad.easeInOut
     
    (see Quad.png)

    Cubic:

    Displays a Cubic transition.

    >Trans.Cubic.easeIn
    >Trans.Cubic.easeOut
    >Trans.Cubic.easeInOut

    (see Cubic.png)

    Quart:

    Displays a Quartetic transition.

    >Trans.Quart.easeIn
    >Trans.Quart.easeOut
    >Trans.Quart.easeInOut

    (see Quart.png)

    Quint:

    Displays a Quintic transition.

    >Trans.Quint.easeIn
    >Trans.Quint.easeOut
    >Trans.Quint.easeInOut

    (see Quint.png)

    Expo:

    Displays an Exponential transition.

    >Trans.Expo.easeIn
    >Trans.Expo.easeOut
    >Trans.Expo.easeInOut

    (see Expo.png)

    Circ:

    Displays a Circular transition.

    >Trans.Circ.easeIn
    >Trans.Circ.easeOut
    >Trans.Circ.easeInOut

    (see Circ.png)

    Sine:

    Displays a Sineousidal transition.

    >Trans.Sine.easeIn
    >Trans.Sine.easeOut
    >Trans.Sine.easeInOut

    (see Sine.png)

    Back:

    >Trans.Back.easeIn
    >Trans.Back.easeOut
    >Trans.Back.easeInOut

    (see Back.png)

    Bounce:

    Bouncy transition.

    >Trans.Bounce.easeIn
    >Trans.Bounce.easeOut
    >Trans.Bounce.easeInOut

    (see Bounce.png)

    Elastic:

    Elastic curve.

    >Trans.Elastic.easeIn
    >Trans.Elastic.easeOut
    >Trans.Elastic.easeInOut

    (see Elastic.png)



*/
this.Trans = {
    linear: function(p) { return p; }
};

(function() {

	var makeTrans = function(transition, params){
	    params = $splat(params);
	    return $extend(transition, {
	        easeIn: function(pos){
	            return transition(pos, params);
	        },
	        easeOut: function(pos){
	            return 1 - transition(1 - pos, params);
	        },
	        easeInOut: function(pos){
	            return (pos <= 0.5) ? transition(2 * pos, params) / 2 : (2 - transition(2 * (1 - pos), params)) / 2;
	        }
	    });
	};
	
	var transitions = {

	    Pow: function(p, x){
	        return Math.pow(p, x[0] || 6);
	    },
	
	    Expo: function(p){
	        return Math.pow(2, 8 * (p - 1));
	    },
	
	    Circ: function(p){
	        return 1 - Math.sin(Math.acos(p));
	    },
	
	    Sine: function(p){
	        return 1 - Math.sin((1 - p) * Math.PI / 2);
	    },
	
	    Back: function(p, x){
	        x = x[0] || 1.618;
	        return Math.pow(p, 2) * ((x + 1) * p - x);
	    },
	
	    Bounce: function(p){
	        var value;
	        for (var a = 0, b = 1; 1; a += b, b /= 2){
	            if (p >= (7 - 4 * a) / 11){
	                value = b * b - Math.pow((11 - 6 * a - 11 * p) / 4, 2);
	                break;
	            }
	        }
	        return value;
	    },
	
	    Elastic: function(p, x){
	        return Math.pow(2, 10 * --p) * Math.cos(20 * p * Math.PI * (x[0] || 1) / 3);
	    }
	
	};
	
	$each(transitions, function(val, key) {
		Trans[key] = makeTrans(val);
	});

	$each(['Quad', 'Cubic', 'Quart', 'Quint'], function(elem, i) {
		Trans[elem] = makeTrans(function(p){
            return Math.pow(p, [i + 2]);
        });
	});
	
})();

/*
   Class: Animation
    
   A Class that can perform animations for generic objects.

   If you are looking for animation transitions please take a look at the <Trans> object.

   Used by:

   <Graph.Plot>
   
   Based on:
   
   Fx.Base from MooTools: <http://mootools.net>.

*/

var Animation = new Class({

    initalize: function(options) {
	   this.setOptions(options);
	},
	
	setOptions: function(options) {
        var opt = {
            duration: 2500,
            fps: 40,
            transition: Trans.Quart.easeInOut,
            compute: $empty,
            complete: $empty
        };
        this.opt = $merge(opt, options || {});
		return this;
	},
	
	getTime: function() {
        return $time();
    },
    
    step: function(){
        var time = this.getTime(), opt = this.opt;
        if (time < this.time + opt.duration){
            var delta = opt.transition((time - this.time) / opt.duration);
            opt.compute(delta);
        } else {
            this.timer = clearInterval(this.timer);
            opt.compute(1);
            opt.complete();
        }
    },

    start: function(){
        this.time = 0;
        this.startTimer();
        return this;
    },

    startTimer: function(){
		var that = this, opt = this.opt;
        if (this.timer) return false;
        this.time = this.getTime() - this.time;
        this.timer = setInterval((function () { that.step(); }), Math.round(1000 / opt.fps));
        return true;
    }
});



/*
 * File: Spacetree.js
 * 
 * Implements the <ST> class and other derived classes.
 *
 * Description:
 *
 * The main idea of the spacetree algorithm is to take the most common tree layout, and to expand nodes that are "context-related" .i.e lying on the path between the root node and a selected node. Useful animations to contract and expand nodes are also included.
 *
 * Inspired by:
 *
 * SpaceTree: Supporting Exploration in Large Node Link Tree, Design Evolution and Empirical Evaluation (Catherine Plaisant, Jesse Grosjean, Benjamin B. Bederson)
 *
 * <http://hcil.cs.umd.edu/trs/2002-05/2002-05.pdf>
 *
 * Disclaimer:
 *
 * This visualization was built from scratch, taking only the paper as inspiration, and only shares some features with the Spacetree.
 *
 */

/*
     Class: ST
     
     The main ST class

     Extends:

     <Loader>

     Parameters:

     canvas - A <Canvas> Class
     config - A configuration/controller object.

     Configuration:
    
     The configuration object can have the following properties (all properties are optional and have a default value)
      
     *General*

     - _orientation_ Sets the orientation layout. Implemented orientations are _left_ (the root node will be placed on the left side of the screen), _top_ (the root node will be placed on top of the screen), _bottom_ and _right_. Default's "left".
     - _levelsToShow_ Depth of the plotted tree. The plotted tree will be pruned in order to fit the specified depth. Default's 2.
     - _subtreeOffset_ Separation offset between subtrees. Default's 8.
     - _siblingOffset_ Separation offset between siblings. Default's 5.
     - _levelDistance_ Distance between levels. Default's 30.
     - _withLabels_ Whether the visualization should use/create labels or not. Default's *true*.

     *Node*
     
     Customize the visualization nodes' shape, color, and other style properties.

     - _Node_

     This object has as properties

     - _overridable_ Determine whether or not nodes properties can be overriden by a particular node. Default's false.

     If given a JSON tree or graph, a node _data_ property contains properties which are the same as defined here but prefixed with 
     a dollar sign (i.e $), the node properties will override the global node properties.

     - _type_ Node type (shape). Possible options are "none", "square", "rectangle", "ellipse" and "circle". Default's "rectangle".
     - _color_ Node color. Default's '#ccb'.
     - _lineWidth_ Line width. If nodes aren't drawn with strokes then this property won't be of any use. Default's 1.
     - _height_ Node height. Used for plotting rectangular nodes. _Width_ and _height_ properties are also used as bounding box for nodes of different shapes. 
     This means that for all shapes you'd have to make sure that the node's shape is contained in the bounding box defined by _width_ and _height_ parameters. Default's 20.
     - _width_ Node width. Used for plotting rectangular nodes and for calculating a node's bounding box. Default's 90.
     - _dim_ An extra parameter used by other complex shapes such as square and circle to determine the shape's diameter. 
     Please notice that even if these complex shapes (square, circle) only use _dim_ for calculating it's diameter property, the complex shape must be 
     contained in the bounding box calculated with the _width_ and _height_ parameters. Default's 15.
     - _align_ Defines a node's alignment. Possible values are "center", "left", "right". Default's "center".

     *Edge*

     Customize the visualization edges' shape, color, and other style properties.

     - _Edge_

     This object has as properties

     - _overridable_ Determine whether or not edges properties can be overriden by a particular edge object. Default's false.

     If given a JSON _complex_ graph (defined in <Loader.loadJSON>), an adjacency _data_ property contains properties which are the same as defined here but prefixed with 
     a dollar sign (i.e $), the adjacency properties will override the global edge properties.

     - _type_ Edge type (shape). Possible options are "none", "line", "quadratic:begin", "quadratic:end", "bezier" and "arrow". Default's "line".
     - _color_ Edge color. Default's '#ccb'.
     - _lineWidth_ Line width. If edges aren't drawn with strokes then this property won't be of any use. Default's 1.
     - _dim_ An extra parameter used by other complex shapes such as quadratic, arrow and bezier to determine the shape's diameter. 

     *Animations*

     - _duration_ Duration of the animation in milliseconds. Default's 700.
     - _fps_ Frames per second. Default's 25.
     - _transition_ One of the transitions defined in the <Animation> class. Default's Quart.easeInOut.
     - _clearCanvas_ Whether to clear canvas on each animation frame or not. Default's true.
     
    *Controller options*

    You can also implement controller functions inside the configuration object. This functions are
    
    - _onBeforeCompute(node)_ This method is called right before performing all computation and animations to the JIT visualization.
    - _onAfterCompute()_ This method is triggered right after all animations or computations for the JIT visualizations ended.
    - _onCreateLabel(domElement, node)_ This method receives the label dom element as first parameter, and the corresponding <Graph.Node> as second parameter. This method will only be called on label creation. Note that a <Graph.Node> is a node from the input tree/graph you provided to the visualization. If you want to know more about what kind of JSON tree/graph format is used to feed the visualizations, you can take a look at <Loader.loadJSON>. This method proves useful when adding events to the labels used by the JIT.
    - _onPlaceLabel(domElement, node)_ This method receives the label dom element as first parameter and the corresponding <Graph.Node> as second parameter. This method is called each time a label has been placed on the visualization, and thus it allows you to update the labels properties, such as size or position. Note that onPlaceLabel will be triggered after updating the labels positions. That means that, for example, the left and top css properties are already updated to match the nodes positions.
    - _onBeforePlotNode(node)_ This method is triggered right before plotting a given node. The _node_ parameter is the <Graph.Node> to be plotted. 
This method is useful for changing a node style right before plotting it.
    - _onAfterPlotNode(node)_ This method is triggered right after plotting a given node. The _node_ parameter is the <Graph.Node> plotted.
    - _onBeforePlotLine(adj)_ This method is triggered right before plotting an edge. The _adj_ parameter is a <Graph.Adjacence> object. 
This method is useful for adding some styles to a particular edge before being plotted.
    - _onAfterPlotLine(adj)_ This method is triggered right after plotting an edge. The _adj_ parameter is the <Graph.Adjacence> plotted.
    - _request(nodeId, level, onComplete)_ This method is used for buffering information into the visualization. When clicking on an empty node,
 the visualization will make a request for this node's subtree, specifying a given level for this subtree. Once this request is completed the _onComplete_ 
object must be called with the given result.

    Example:

    Here goes a complete example. In most cases you won't be forced to implement all properties and methods. In fact, 
    all configuration properties  have the default value assigned.

    I won't be instanciating a <Canvas> class here. If you want to know more about instanciating a <Canvas> class 
    please take a look at the <Canvas> class documentation.

    (start code js)
      var st = new ST(canvas, {
        orientation: "left",
        levelsToShow: 2,
        subtreeOffset: 8,
        siblingOffset: 5,
        levelDistance: 30,
        withLabels: true,
        Node: {
          overridable: false,
          type: 'rectangle',
          color: '#ccb',
          lineWidth: 1,
          height: 20,
          width: 90,
          dim: 15,
          align: "center"
        },
        Edge: {
          overridable: false,
          type: 'line',
          color: '#ccc',
          dim: 15,
          lineWidth: 1
        },
        duration: 700,
        fps: 25,
        transition: Trans.Quart.easeInOut,
        clearCanvas: true,
        
        onBeforeCompute: function(node) {
          //do something onBeforeCompute
        },
        onAfterCompute:  function () {
          //do something onAfterCompute
        },
        onCreateLabel:   function(domElement, node) {
          //do something onCreateLabel
        },
        onPlaceLabel:    function(domElement, node) {
          //do something onPlaceLabel
        },
        onBeforePlotNode:function(node) {
          //do something onBeforePlotNode
        },
        onAfterPlotNode: function(node) {
          //do something onAfterPlotNode
        },
        onBeforePlotLine:function(adj) {
          //do something onBeforePlotLine
        },
        onAfterPlotLine: function(adj) {
          //do something onAfterPlotLine
        },
        request:         false

      });
    (end code)

    Instance Properties:

    - _graph_ Access a <Graph> instance.
    - _op_ Access a <ST.Op> instance.
    - _fx_ Access a  <ST.Plot> instance.
 */

this.ST= (function() {
    //Define some private methods first...
    //Lowest Common Ancestor
    var lca;
    //Nodes in path
    var nodesInPath = [];
    //Nodes to contract
    function getNodesToHide(node) {
        node = node || this.clickedNode;
        var Geom = this.geom, GUtil = Graph.Util;
        var graph = this.graph;
        var canvas = this.canvas;
        var level = node._depth, nodeArray = [];
        GUtil.eachNode(graph, function(n) {
            if(n._depth <= level && n.exist && !n.selected) {
                nodeArray.push(n);
            }
        });
        var leafLevel = Geom.getRightLevelToShow(node, canvas);
        GUtil.eachLevel(node, leafLevel, leafLevel, function(n) {
            if(n.exist && !n.selected) nodeArray.push(n);
        });
        return nodeArray;       
     };
    //Nodes to expand
     function getNodesToShow(node) {
        var nodeArray= [], GUtil = Graph.Util;
        node = node || this.clickedNode;
        GUtil.eachLevel(this.clickedNode, 0, this.config.levelsToShow, function(n) {
            if(n.drawn && !GUtil.anySubnode(n, "drawn")) {
                nodeArray.push(n);
            }
        });
        return nodeArray;
     };
     //Lowest Common Ancestor
     function getLCA(node) {
         if (nodesInPath.length == 0) {
            lca = node? node.id : false;
            return;
         }
         //Preprocess
         var GUtil = Graph.Util, graph = this.graph, root = this.root, treeDepth = 0;
         GUtil.eachNode(graph, function(n) { 
            treeDepth = (n._depth > treeDepth)? n._depth : treeDepth; 
         });
         var nr = Math.sqrt(treeDepth), p = {};
         (function dfs(n) {
             if(n._depth < nr) {
                 p[n.id] = root;
             } else {
                 var par = GUtil.getParents(n)[0].id;
                 if(!(n._depth % nr)) {
                     p[n.id] = par;
                 } else {
                     p[n.id] = p[par];
                 }
             }
             GUtil.eachSubnode(n, dfs);
         })(graph.getNode(root));
         
         //Find LCA algorithm
         function findLCA(n, m) {
           while(p[n] != p[m]) {
               var noden = graph.getNode(n), nodem = graph.getNode(m);
               if(n._depth > m._depth) {
                   n = p[n];
               } else {
                   m = p[m];
               }
           }
           
           while(n != m) {
               var noden = graph.getNode(n), nodem = graph.getNode(m);
               if(n._depth > m._depth) {
                   n = GUtil.getParents(noden)[0].id;
               } else {
                   m = GUtil.getParents(nodem)[0].id;
               }
           }
           return n;  
         };
         //Reduce LCA for all nodes
         lca = root;
         for(var i = 0; i < nodesInPath.length; i++) {
             lca = findLCA(lca, nodesInPath[i]);
         }
     };
    
    //Now define the actual class.    
    return new Class({
    
        Implements: Loader,
        
        initialize: function(canvas, controller) {
            var innerController = {
                onBeforeCompute: $empty,
                onAfterCompute:  $empty,
                onCreateLabel:   $empty,
                onPlaceLabel:    $empty,
                onComplete:      $empty,
                onBeforePlotNode:$empty,
                onAfterPlotNode: $empty,
                onBeforePlotLine:$empty,
                onAfterPlotLine: $empty,
                request:         false
            };
            
            var config= {
                orientation: "left",
                labelContainer: canvas.id + '-label',
                levelsToShow: 2,
                subtreeOffset: 8,
                siblingOffset: 5,
                levelDistance: 30,
                withLabels: true,
                clearCanvas: true,
                Node: {
                    overridable: false,
                    type: 'rectangle',
                    color: '#ccb',
                    lineWidth: 1,
                    height: 20,
                    width: 90,
                    dim: 15,
                    align: "center"
                },
                Edge: {
                    overridable: false,
                    type: 'line',
                    color: '#ccc',
                    dim: 15,
                    lineWidth: 1
                },
                duration: 700,
                fps: 25,
                transition: Trans.Quart.easeInOut
            };
            
            this.controller = this.config = $merge(config, innerController, controller);
            this.canvas = canvas;
            this.graphOptions = {
                'complex': true
            };
            this.graph = new Graph(this.graphOptions);
            this.fx = new ST.Plot(this);
            this.op = new ST.Op(this);
            this.group = new ST.Group(this);
            this.geom = new ST.Geom(this);
            this.clickedNode=  null;
            
        },
    
        /*
         Method: plot
        
         Plots the tree. Usually this method is called right after computing nodes' positions.

        */  
        plot: function() { this.fx.plot(this.controller); },
    
      
        /*
         Method: switchPosition
        
         Switches the tree orientation.

         Parameters:

        pos - The new tree orientation. Possible values are "top", "left", "right" and "bottom".
        onComplete - _optional_ This callback is called once the "switching" animation is complete.

         Example:

         (start code js)
           st.switchPosition("right", {
            onComplete: function() {
              alert('completed!');
            } 
           });
         (end code)
        */  
        switchPosition: function(pos, onComplete) {
          var Geom = this.geom, Plot = this.fx, that = this;
          if(!Plot.busy) {
              Plot.busy = true;
              this.contract({
                  onComplete: function() {
                      Geom.switchOrientation(pos);
                      that.compute('endPos', false);
                      Plot.busy = false;
                      that.onClick(that.clickedNode.id, onComplete);
                  }
              }, pos);
          }
        },

       addNodeInPath: function(id) {
           nodesInPath.push(id);
       },       

       clearNodesInPath: function(id) {
           nodesInPath.length = 0;
       },
       
         
        
       /*
         Method: refresh
        
         Computes nodes' positions and replots the tree.
         
       */
       refresh: function() {
           this.reposition();
           this.select((this.clickedNode && this.clickedNode.id) || this.root);
       },    

       reposition: function() {
            Graph.Util.computeLevels(this.graph, this.root, 0, "ignore");
             this.geom.setRightLevelToShow(this.clickedNode, this.canvas);
            Graph.Util.eachNode(this.graph, function(n) {
                if(n.exist) n.drawn = true;
            });
            this.compute('endPos');
        },
    
        /*
         Method: compute
        
         Computes nodes' positions.

        */  
        compute: function (property, computeLevels) {
            var prop = property || 'startPos';
            var node = this.graph.getNode(this.root);
            $extend(node, {
                'drawn':true,
                'exist':true,
                'selected':true
            });
            if(!!computeLevels || !("_depth" in node))
                Graph.Util.computeLevels(this.graph, this.root, 0, "ignore");
            getLCA.call(this, this.clickedNode);
            this.computePositions(node, $C(0, 0), prop);
        },
        
        computePositions: function (node, initialPos, property, contracted) {
            var GUtil = Graph.Util, geom = this.geom,
            contracted = (arguments.length == 3) || contracted;
    
            if(lca && (node.id == lca) && contracted) 
                  contracted = false;
            
            node[property] = initialPos;
    
            var ch = [];
            GUtil.eachSubnode(node, function(n) {
                ch.push(n);
            });
            
            if (ch.length > 0) {
                var baseHeight   = geom.getBaseSize(node, contracted);
                var prevBaseSize = geom.getBaseSize(ch[0], contracted, 'available');
                var subtreeOffset   = (ch.length == 1)? this.config.subtreeOffset : baseHeight - prevBaseSize;
                var firstPos= ch[0][property]= geom.getFirstPos(node, initialPos, subtreeOffset);
                this.computePositions(ch[0], firstPos, property, contracted);
                for(var i=1; i<ch.length; i++) {
                    var leaf = !GUtil.anySubnode(ch[i], "exist") || !GUtil.anySubnode(ch[i -1], "exist");
                    var nextBaseSize = geom.getBaseSize(ch[i], contracted, 'available');
                    var siblingOffset = leaf? (geom.getSize(ch[i], true) + geom.getSize(ch[i -1], true)) / 2 : (prevBaseSize + nextBaseSize) / 2;
                    firstPos = geom.nextPosition(firstPos, siblingOffset);
                    prevBaseSize = nextBaseSize;
                    this.computePositions(ch[i], firstPos, property, contracted);
                }
            }
        },
    
          requestNodes: function(node, onComplete) {
            var handler = $merge(this.controller, onComplete), 
            lev = this.config.levelsToShow, GUtil = Graph.Util;
            if(handler.request) {
                var leaves = [], d = node._depth;
                GUtil.eachLevel(node, 0, lev, function(n) {
                    if(n.drawn && 
                     !GUtil.anySubnode(n)) {
                     leaves.push(n);
                     n._level = lev - (n._depth - d);
                    }
                });
                this.group.requestNodes(leaves, handler);
            }
              else
                handler.onComplete();
          },
     
          contract: function(onComplete, switched) {
            var orn  = this.config.orientation;
            var Geom = this.geom, Group = this.group;
            if(switched) Geom.switchOrientation(switched);
            var nodes = getNodesToHide.call(this);
            if(switched) Geom.switchOrientation(orn);
            Group.contract(nodes, $merge(this.controller, onComplete));
          },
      
         move: function(node, onComplete) {
            this.compute('endPos', false);
            var move = onComplete.Move, offset = {
                'x': move.offsetX,
                'y': move.offsetY 
            };
            this.geom.translate(node.endPos.add(offset).$scale(-1), "endPos");
            this.fx.animate($merge(this.controller, { modes: ['linear'] }, onComplete));
         },
      
      
        expand: function (node, onComplete) {
            var nodeArray = getNodesToShow.call(this, node);
            this.group.expand(nodeArray, $merge(this.controller, onComplete));
        },
    
    
        selectPath: function(node) {
          var GUtil = Graph.Util, that = this;
          GUtil.eachNode(this.graph, function(n) { n.selected = false; }); 
          function path(node) {
              if(node == null || node.selected) return;
              node.selected = true;
              $each(that.group.getSiblings([node])[node.id], 
              function(n) { 
                   n.exist = true; 
                   n.drawn = true; 
              });    
              var parents = GUtil.getParents(node);
              parents = (parents.length > 0)? parents[0] : null;
              path(parents);
          };
          for(var i=0, ns = [node.id].concat(nodesInPath); i < ns.length; i++) {
              path(this.graph.getNode(ns[i]));
          }
        },
      
        /*
           Method: addSubtree
        
            Adds a subtree, performing optionally an animation.
        
           Parameters:
              subtree - A JSON Tree object. See also <Loader.loadJSON>.
              method - Set this to "animate" if you want to animate the tree after adding the subtree. You can also set this parameter to "replot" to just replot the subtree.
              onComplete - _optional_ An action to perform after the animation (if any).
    
           Example:

           (start code js)
             st.addSubtree(json, 'animate', {
                onComplete: function() {
                  alert('complete!');
                }
             });
           (end code)
        */
        addSubtree: function(subtree, method, onComplete) {
            if(method == 'replot') {
                this.op.sum(subtree, $extend({ type: 'replot' }, onComplete || {}));
            } else if (method == 'animate') {
                this.op.sum(subtree, $extend({ type: 'fade:seq' }, onComplete || {}));
            }
        },
    
        /*
           Method: removeSubtree
        
            Removes a subtree, performing optionally an animation.
        
           Parameters:
              id - The _id_ of the subtree to be removed.
              removeRoot - Remove the root of the subtree or only its subnodes.
              method - Set this to "animate" if you want to animate the tree after removing the subtree. You can also set this parameter to "replot" to just replot the subtree.
              onComplete - _optional_ An action to perform after the animation (if any).

          Example:

          (start code js)
            st.removeSubtree('idOfSubtreeToBeRemoved', false, 'animate', {
              onComplete: function() {
                alert('complete!');
              }
            });
          (end code)
    
        */
        removeSubtree: function(id, removeRoot, method, onComplete) {
            var node = this.graph.getNode(id), subids = [];
            Graph.Util.eachLevel(node, +!removeRoot, false, function(n) {
                subids.push(n.id);
            });
            if(method == 'replot') {
                this.op.removeNode(subids, $extend({ type: 'replot' }, onComplete || {}));
            } else if (method == 'animate') {
                this.op.removeNode(subids, $extend({ type: 'fade:seq'}, onComplete || {}));
            }
        },
    
        /*
           Method: select
        
            Selects a sepecific node in the Spacetree without performing an animation. Useful when selecting 
            nodes which are currently hidden or deep inside the tree.

          Parameters:
            id - The id of the node to select.
            onComplete - _optional_ onComplete callback.

          Example:
          (start code js)
            st.select('mynodeid', {
              onComplete: function() {
                alert('complete!');
              }
            });
          (end code)
        */
        select: function(id, onComplete) {
            var group = this.group, geom = this.geom;
            var node=  this.graph.getNode(id), canvas = this.canvas;
            var root  = this.graph.getNode(this.root);
            var complete = $merge(this.controller, onComplete);
            var that = this;
    
            complete.onBeforeCompute(node);
            this.selectPath(node);
            this.clickedNode= node;
            this.requestNodes(node, {
                onComplete: function(){
                    group.hide(group.prepare(getNodesToHide.call(that)), complete);
                    geom.setRightLevelToShow(node, canvas);
                    that.compute("pos");
                    Graph.Util.eachNode(that.graph, function(n) { 
                        var pos = n.pos.getc(true);
                        n.startPos.setc(pos.x, pos.y);
                        n.endPos.setc(pos.x, pos.y);
                        n.visited = false; 
                    });
                    that.geom.translate(node.endPos.scale(-1), ["pos", "startPos", "endPos"]);
                    group.show(getNodesToShow.call(that));              
                    that.plot();
                    complete.onAfterCompute(that.clickedNode);
                    complete.onComplete();
                }
            });     
        },
    
      /*
         Method: onClick
    
        This method is called when clicking on a tree node. It mainly performs all calculations and the animation of contracting, translating and expanding pertinent nodes.
        
            
         Parameters:
        
            id - A node id.
            options - A group of options and callbacks such as

            - _onComplete_ an object callback called when the animation finishes.

        Example:

        (start code js)
          st.onClick('mynodeid', {
            onComplete: function() {
              alert('yay!');
            }
          });
        (end code)
    
        */    
      onClick: function (id, options) {
        var canvas = this.canvas, that = this, Fx = this.fx, Util = Graph.Util, Geom = this.geom;
        var innerController = {
            Move: {
              offsetX: 0,
              offsetY: 0  
            },
            onBeforeRequest: $empty,
            onBeforeContract: $empty,
            onBeforeMove: $empty,
            onBeforeExpand: $empty
        };
        var complete = $merge(this.controller, innerController, options);
        
        if(!this.busy) {
            this.busy= true;
            var node=  this.graph.getNode(id);
            this.selectPath(node, this.clickedNode);
            this.clickedNode= node;
            complete.onBeforeCompute(node);
            complete.onBeforeRequest(node);
            this.requestNodes(node, {
                onComplete: function() {
                    complete.onBeforeContract(node);
                    that.contract({
                        onComplete: function() {
                            Geom.setRightLevelToShow(node, canvas);
                            complete.onBeforeMove(node);
                            that.move(node, {
                                Move: complete.Move,
                                onComplete: function() {
                                    complete.onBeforeExpand(node);
                                    that.expand(node, {
                                        onComplete: function() {
                                            that.busy = false;
                                            complete.onAfterCompute(id);
                                            complete.onComplete();
                                        }
                                    }); //expand
                                }
                            }); //move
                        }
                    });//contract
                }
            });//request
        }
      }
    });

})();

/*
   Class: ST.Op
    
   Performs advanced operations on trees and graphs.

   Extends:

   All <Graph.Op> methods

   Access:

   This instance can be accessed with the _op_ parameter of the st instance created.

   Example:

   (start code js)
    var st = new ST(canvas, config);
    st.op.morph //or can also call any other <Graph.Op> method
   (end code)

*/
ST.Op = new Class({
    Implements: Graph.Op,
    
    initialize: function(viz) {
        this.viz = viz;
    }
});

/*
    
     Performs operations on group of nodes.

*/
ST.Group = new Class({
    
    initialize: function(viz) {
        this.viz = viz;
        this.canvas = viz.canvas;
        this.config = viz.config;
        this.animation = new Animation;
        this.nodes = null;
        this.siblings = null;
        this.bbs = null;
    },
    
    /*
    
       Calls the request method on the controller to request a subtree for each node. 
    */
    requestNodes: function(nodes, controller) {
        var counter = 0, len = nodes.length, nodeSelected = {};
        var complete = function() { controller.onComplete(); };
        var viz = this.viz;
        if(len == 0) complete();
        for(var i=0; i<len; i++) {
            nodeSelected[nodes[i].id] = nodes[i];
            controller.request(nodes[i].id, nodes[i]._level, {
                onComplete: function(nodeId, data) {
                    if(data && data.children) {
                        data.id = nodeId;
                        viz.op.sum(data, { type: 'nothing' });
                    }
                    if(++counter == len) {
                        Graph.Util.computeLevels(viz.graph, viz.root, 0);
                        complete();
                    }
                }
            });
        }
    },
    
    /*
    
       Collapses group of nodes. 
    */
    contract: function(nodes, controller) {
        var GUtil = Graph.Util;
        var viz = this.viz;
        var that = this;

        nodes = this.prepare(nodes);
        this.animation.setOptions($merge(controller, {
            $animating: false,
            compute: function(delta) {
              if(delta == 1) delta = .99;
              that.plotStep(1 - delta, controller, this.$animating);
              this.$animating = 'contract';
            },
            
            complete: function() {
                that.hide(nodes, controller);
            }       
        })).start();
    },
    
    hide: function(nodes, controller) {
        var GUtil = Graph.Util, viz = this.viz;
        for(var i=0; i<nodes.length; i++) {
            //TODO nodes are requested on demand, but not
            //deleted when hidden. Would that be a good feature? 
            //Currenty that feature is buggy, so I'll turn it off
            if (true || !controller || !controller.request) {
                GUtil.eachLevel(nodes[i], 1, false, function(elem){
                    if (elem.exist) {
                        $extend(elem, {
                            'drawn': false,
                            'exist': false
                        });
                    }
                });
            } else {
                var ids = [];
                GUtil.eachLevel(nodes[i], 1, false, function(n) {
                    ids.push(n.id);
                });
                viz.op.removeNode(ids, { 'type': 'nothing' });
                viz.fx.clearLabels();
            }
        }
        controller.onComplete();
    },    
    

    /*
    
       Expands group of nodes. 
    */
    expand: function(nodes, controller) {
        var that = this, GUtil = Graph.Util;
        this.show(nodes);
        this.animation.setOptions($merge(controller, {
            $animating: false,
            compute: function(delta) {
                that.plotStep(delta, controller, this.$animating);
                this.$animating = 'expand';
            },
            
            complete: function() {
                that.plotStep(undefined, controller, false);
                controller.onComplete();
            }       
        })).start();
        
    },
    
    show: function(nodes) {
        var GUtil = Graph.Util, config = this.config;
        this.prepare(nodes);
        $each(nodes, function(n) { 
            GUtil.eachLevel(n, 0, config.levelsToShow, function(n) {
                if(n.exist) n.drawn = true;
            });     
        });
    },
    
    prepare: function(nodes) {
        this.nodes = this.getNodesWithChildren(nodes);
        this.siblings = this.getSiblings(this.nodes);
        this.bbs = this.getBoundingBoxes(this.nodes);
        return this.nodes;
    },
    
    /*
    
       Filters an array of nodes leaving only nodes with children.
    */
    getNodesWithChildren: function(nodes) {
        var ans = [], GUtil = Graph.Util;
        for(var i=0; i<nodes.length; i++) {
            if(GUtil.anySubnode(nodes[i], "exist")) {
                ans.push(nodes[i]);
            }
        }
        return ans;
    },
    
    plotStep: function(delta, controller, animating) {
      var viz = this.viz, 
      canvas = viz.canvas, 
      ctx = canvas.getCtx(),
      bbs = this.bbs, 
      siblings = this.siblings, 
      nodes = this.nodes;
      
      for(var i=0; i<nodes.length; i++) {
        ctx.save();
        var node= nodes[i];
        var bb= bbs[i];
        canvas.clearRectangle(bb.top, bb.right, bb.bottom, bb.left);
        viz.fx.plotSubtree(node, controller, delta, animating);                
        ctx.restore();
        $each(siblings[node.id], function(elem) {
            viz.fx.plotNode(elem, canvas, false);
        });
      }
    },
    
    getSiblings: function(nodes) {
        var siblings = {}, GUtil = Graph.Util;
        $each(nodes, function(n) {
            var par = GUtil.getParents(n);
            if (par.length == 0) {
                siblings[n.id] = [n];
            } else {
                var ans = [];
                GUtil.eachSubnode(par[0], function(sn) {
                    ans.push(sn);
                });
                siblings[n.id] = ans;
            }
        });
        return siblings;
    },
    
    getBoundingBoxes: function(nodes) {
        var bbs = [], geom = this.viz.geom;
        $each(nodes, function(n) {
            bbs.push(geom.getBoundingBox(n));
        });
        return bbs;
    }
});

/*
   Class: ST.Geom

    Performs low level geometrical computations.

   Access:

   This instance can be accessed with the _geom_ parameter of the st instance created.

   Example:

   (start code js)
    var st = new ST(canvas, config);
    st.geom.translate //or can also call any other <ST.Geom> method
   (end code)

*/

ST.Geom = new Class({
    
    initialize: function(viz) {
        this.viz = viz;
        this.config = viz.config;
        this.node = viz.config.Node;
        this.edge = viz.config.Edge;
    },
    
    /*
       Method: translate
       
       Applies a translation to the tree.

       Parameters:

       pos - A <Complex> number specifying translation vector.
       prop - A <Graph.Node> position property ('pos', 'startPos' or 'endPos').

       Example:

       (start code js)
         st.geom.translate(new Complex(300, 100), 'endPos');
       (end code)
    */  
    translate: function(pos, prop) {
        prop = $splat(prop);
        Graph.Util.eachNode(this.viz.graph, function(elem) {
            $each(prop, function(p) { elem[p].$add(pos); });
        });
    },

    /*
       Changes the tree current orientation to the one specified.

       You should usually use <ST.switchPosition> instead.
    */  
    switchOrientation: function() {
        var args = arguments;
        if(args.length > 0) {
          this.config.orientation = args[0];
        } else {
          var s = this.dispatch("bottom", "top", "left", "right");
          this.config.orientation = s;   
        }
    },

    /*
       Makes a value dispatch according to the current layout
       Works like a CSS property, either _top-right-bottom-left_ or _top|bottom - left|right_.
     */
    dispatch: function() {
        var args = arguments, len = args.length, s = this.config.orientation;
        var val = function(a) { return typeof a == 'function'? a() : a; };
        if(len == 2) {
            return (s == "top" || s == "bottom")? val(args[0]) : val(args[1]);
        } else if(len == 4) {
            switch(s) {
                case "top": return val(args[0]);
                case "right": return val(args[1]);
                case "bottom": return val(args[2]);
                case "left": return val(args[3]);
            }
        }
    },

    /*
       Returns label height or with, depending on the tree current orientation.
    */  
    getSize: function(n, invert) {
        var node = this.node, data = n.data;
        var cond = this.node.overridable, siblingOffset = this.config.siblingOffset;
        var w = (cond && data.$width || node.width) + siblingOffset;
        var h = (cond && data.$height || node.height) + siblingOffset;
        if(!invert)
            return this.dispatch(h, w);
        else
            return this.dispatch(w, h);
    },
    
    /*
       Calculates the max width and height for a tree's level.
    */  
    getMaxSiblingWidthAndHeight: function(node) {
        var dim = this.node, GUtil = Graph.Util, graph = this.viz.graph;
        var level = node._depth;
        if(this.node.overridable) {
            var w = -1, h = -1;
            GUtil.eachNode(graph, function(n) {
                if(n._depth == level) {
                    var dw = n.data.$width || dim.width;
                    var dh = n.data.$height || dim.height;
                    w = (w < dw)? dw : w;
                    h = (h < dh)? dh : h;
                }
            });
            return {
                'width':  w,
                'height': h
            };
        } else {
            return this.node;
        }
    },

    /*
       Method: getBoundingBox
       
       Calculates a tree bounding box for a given node. TODO: refactor

       Parameters:

       node - A <Graph.Node>, the root of the subtree to calculate its bounding box.
    */  
    getBoundingBox: function (node) {
        var dim = this.node, pos = node.pos, siblingOffset = this.config.siblingOffset;
        var GUtil = Graph.Util;
        var calc = function(level, n) {
            if(level === 0 || !Graph.Util.anySubnode(n, "exist")) {
                calc.boundary = calc.boundary || { 'w': -1, 'h': -1 };
                var w = n.data.$width || dim.width;
                var h = n.data.$height || dim.height;
                var b = calc.boundary;
                b.w = (w > b.w)? w : b.w;
                b.h = (h > b.h)? h : b.h;
                calc.leaf = (calc.leaf && calc.leaf._depth > n._depth)? calc.leaf : n;
                return true;                
            }
            return false;
        };
        var baseSize = this.getTreeBaseSize(node, Number.MAX_VALUE, calc);
        var b = calc.boundary;
        var leaf = calc.leaf;
        var root = node;
        var rw = root.data.$width || dim.width;
        var rh = root.data.$height || dim.height;
        
        if(dim.align == "left") {
            return this.dispatch({
                left: root.pos.x - baseSize / 2,
                bottom: leaf.pos.y + b.h,
                top: root.pos.y + rh,
                right: root.pos.x + baseSize / 2
            }, {
                left: leaf.pos.x,
                bottom: root.pos.y + baseSize / 2,
                top: root.pos.y - baseSize / 2,
                right: root.pos.x
            }, {
                left: root.pos.x - baseSize / 2,
                bottom: root.pos.y,
                top: leaf.pos.y - b.h,
                right: root.pos.x + baseSize / 2
            }, {
                left: root.pos.x + rw,
                bottom: root.pos.y + baseSize / 2,
                top: root.pos.y - baseSize / 2,
                right: leaf.pos.x + b.w
            });
        } else if(dim.align == "center") {
            return this.dispatch({
                left: root.pos.x - baseSize / 2,
                bottom: leaf.pos.y + b.h / 2,
                top: root.pos.y + rh / 2,
                right: root.pos.x + baseSize / 2
            }, {
                left: leaf.pos.x - b.w / 2,
                bottom: root.pos.y + baseSize / 2,
                top: root.pos.y - baseSize / 2,
                right: root.pos.x - rw / 2
            }, {
                left: root.pos.x - baseSize / 2,
                bottom: root.pos.y - rh / 2,
                top: leaf.pos.y - b.h / 2,
                right: root.pos.x + baseSize / 2
            }, {
                left: root.pos.x + rw / 2,
                bottom: root.pos.y + baseSize / 2,
                top: root.pos.y - baseSize / 2,
                right: leaf.pos.x + b.w / 2
            });
        } else if(dim.align == "right") {
            return this.dispatch({
                left: root.pos.x - baseSize / 2,
                bottom: leaf.pos.y,
                top: root.pos.y,
                right: root.pos.x + baseSize / 2
            }, {
                left: leaf.pos.x - b.w,
                bottom: root.pos.y + baseSize / 2,
                top: root.pos.y - baseSize / 2,
                right: root.pos.x
            }, {
                left: root.pos.x - baseSize / 2,
                bottom: root.pos.y - rh,
                top: leaf.pos.y - b.h,
                right: root.pos.x + baseSize / 2
            }, {
                left: root.pos.x,
                bottom: root.pos.y + baseSize / 2,
                top: root.pos.y - baseSize / 2,
                right: leaf.pos.x + b.w
            });
        } else throw "align: not implemented";
     },

    /*
       Calculates a subtree base size.
    */  
    getBaseSize: function(node, contracted, type) {
        if(contracted) {
            if(type == 'available') 
             return this.getSize(node, true);
            else
             return this.getTreeBaseSize(node, 1, function(level, node) {
                 return level === 0 && node.exist;
             });
        }
        return this.getTreeBaseSize(node, Number.MAX_VALUE, function(level, n) {
            return level === 0 || !Graph.Util.anySubnode(n, "exist");
        });
    },

    /*
       Calculates a subtree base size. This is an utility function used by _getBaseSize_
    */  
    getTreeBaseSize: function(node, level, leaf) {
        var size = this.getSize(node, true), baseHeight = 0, that = this;
        if(leaf(level, node)) return size;
        if(level === 0) return 0;
        Graph.Util.eachSubnode(node, function(elem) {
            baseHeight += that.getTreeBaseSize(elem, level -1, leaf);
        });
        return (size > baseHeight? size : baseHeight) + this.config.subtreeOffset;
    },


    /*
       Method: getEdge
       
       Returns a Complex instance with the begin or end position of the edge to be plotted.

       Parameters:

       node - A <Graph.Node> that is connected to this edge.
       type - Returns the begin or end edge position. Possible values are 'begin' or 'end'.

       Returns:

       A <Complex> number specifying the begin or end position.
    */  
    getEdge: function(node, type) {
        var $C = function(a, b) { 
          return function(){
            return node.pos.add(new Complex(a, b));
          }; 
        };
        var dim = this.node;
        var cond = this.node.overridable, data = node.data;
        var w = cond && data.$width || dim.width;
        var h = cond && data.$height || dim.height;
        if(type == 'begin') {
            if(dim.align == "center") {
                return this.dispatch($C(0, h/2), $C(-w/2, 0),
                                     $C(0, -h/2),$C(w/2, 0));
            } else if(dim.align == "left") {
                return this.dispatch($C(0, h), $C(0, 0),
                                     $C(0, 0), $C(w, 0));
            } else if(dim.align == "right") {
                return this.dispatch($C(0, 0), $C(-w, 0),
                                     $C(0, -h),$C(0, 0));
            } else throw "align: not implemented";
            
            
        } else if(type == 'end') {
            if(dim.align == "center") {
                return this.dispatch($C(0, -h/2), $C(w/2, 0),
                                     $C(0, h/2),  $C(-w/2, 0));
            } else if(dim.align == "left") {
                return this.dispatch($C(0, 0), $C(w, 0),
                                     $C(0, h), $C(0, 0));
            } else if(dim.align == "right") {
                return this.dispatch($C(0, -h),$C(0, 0),
                                     $C(0, 0), $C(-w, 0));
            } else throw "align: not implemented";
        }
    },

    /*
       Adjusts the tree position due to canvas scaling or translation.
    */  
    getScaledTreePosition: function(node, scale) {
        var dim = this.node;
        var cond = this.node.overridable, data = node.data;
        var w = (cond && data.$width || dim.width);
        var h = (cond && data.$height || dim.height);
        var $C = function(a, b) { 
          return function(){
            return node.pos.add(new Complex(a, b)).$scale(1 - scale);
          }; 
        };
        if(dim.align == "left") {
            return this.dispatch($C(0, h), $C(0, 0),
                                 $C(0, 0), $C(w, 0));
        } else if(dim.align == "center") {
            return this.dispatch($C(0, h / 2), $C(-w / 2, 0),
                                 $C(0, -h / 2),$C(w / 2, 0));
        } else if(dim.align == "right") {
            return this.dispatch($C(0, 0), $C(-w, 0),
                                 $C(0, -h),$C(0, 0));
        } else throw "align: not implemented"
    },

    /*
       Method: treeFitsInCanvas
       
       Returns a Boolean if the current subtree fits in canvas.

       Parameters:

       node - A <Graph.Node> which is the current root of the subtree.
       canvas - The <Canvas> object.
       level - The depth of the subtree to be considered.
    */  
    treeFitsInCanvas: function(node, canvas, level) {
        var csize = canvas.getSize(node);
        var size = this.dispatch(csize.width, csize.height);
        var baseSize = this.getTreeBaseSize(node, level, function(level, node) { 
          return level === 0 || !Graph.Util.anySubnode(node);
        });
        return (baseSize < size);
    },
    
    /*
       Calculates the _first_ children position given a node position.
    */  
    getFirstPos: function(node, initialPos, baseHeight) {
        var $C = function(a, b) { 
          return function() {
            return new Complex(a, b);
          }; 
        };
        var msize = this.getMaxSiblingWidthAndHeight(node);
        var nSize = {
            'data': {
                '$width': msize.width,
                '$height': msize.height
            }
        };
        var size = this.getSize(nSize) + this.config.levelDistance;
        var factor = -baseHeight / 2 + this.config.subtreeOffset / 2;
        return this.dispatch($C(initialPos.x + factor, initialPos.y + size),
                             $C(initialPos.x - size, initialPos.y + factor),
                             $C(initialPos.x + factor, initialPos.y - size),
                             $C(initialPos.x + size, initialPos.y + factor));
    },
    
    /*
       Calculates a siblings node position given a node position.
    */  
    nextPosition: function(firstPos, siblingOffset) {
        var $C = function(a, b) { 
          return function(){
            return new Complex(a, b);
          }; 
        };
        return this.dispatch($C(firstPos.x + siblingOffset, firstPos.y),
                             $C(firstPos.x, firstPos.y + siblingOffset),
                             $C(firstPos.x + siblingOffset, firstPos.y),
                             $C(firstPos.x, firstPos.y + siblingOffset));
    },
    
    /*
       Hides levels of the tree until it properly fits in canvas.
    */  
    setRightLevelToShow: function(node, canvas) {
        var level = this.getRightLevelToShow(node, canvas), fx = this.viz.fx;
        Graph.Util.eachLevel(node, 0, this.config.levelsToShow, function(n) {
            var d = n._depth - node._depth;
            if(d > level) {
                n.drawn = false; 
                n.exist = false; 
                fx.hideLabel(n, false);
            } else {
                n.exist = true;
            }
        });
        node.drawn= true;
    },
    
    /*
       Returns the right level to show for the current tree in order to fit in canvas.
    */  
    getRightLevelToShow: function(node, canvas) {
        var level = this.config.levelsToShow;
        while(!this.treeFitsInCanvas(node, canvas, level) && level > 1) { level-- ; }
        return level;
    }

});

/*
   Object: ST.Plot
    
   Performs plotting operations.

   Extends:

   All <Graph.Plot> methods

   Access:

   This instance can be accessed with the _fx_ parameter of the st instance created.

   Example:

   (start code js)
    var st = new ST(canvas, config);
    st.fx.placeLabel //or can also call any other <ST.Plot> method
   (end code)


*/
ST.Plot = new Class({
    
    Implements: Graph.Plot,
    
    initialize: function(viz) {
        this.viz = viz;
        this.config = viz.config;
        this.node = this.config.Node;
        this.edge = this.config.Edge;
        this.animation = new Animation;
        this.nodeTypes = new ST.Plot.NodeTypes;
        this.edgeTypes = new ST.Plot.EdgeTypes;        
    },
    
    /*
       Plots a subtree from the spacetree.
    */
    plotSubtree: function(node, opt, scale, animating) {
        var viz = this.viz, canvas = viz.canvas;
        scale = Math.min(Math.max(0.001, scale), 1);
        if(scale >= 0) {
            node.drawn = false;     
            var ctx = canvas.getCtx();
            var diff = viz.geom.getScaledTreePosition(node, scale);
            ctx.translate(diff.x, diff.y);
            ctx.scale(scale, scale);
        }
        this.plotTree(node, !scale, opt, animating);
        if(scale >= 0) node.drawn = true;
    },
    /*
       Plots a Subtree.
    */
    plotTree: function(node, plotLabel, opt, animating) {
        var that = this, 
        viz = this.viz, 
        canvas = viz.canvas,
        ctx = canvas.getCtx();
        Graph.Util.eachSubnode(node, function(elem) {
            if(elem.exist) {
                if(elem.drawn) {
                    var adj = node.getAdjacency(elem.id);
                    !animating && opt.onBeforePlotLine(adj);
                    ctx.globalAlpha = Math.min(node.alpha, elem.alpha);
                    that.plotLine(adj, canvas, animating);
                    !animating && opt.onAfterPlotLine(adj);
                }
                that.plotTree(elem, plotLabel, opt, animating);
            }
        });

        if(node.drawn) {
            ctx.globalAlpha = node.alpha;
            !animating && opt.onBeforePlotNode(node);
            this.plotNode(node, canvas, animating);
            !animating && opt.onAfterPlotNode(node);
            if(plotLabel && ctx.globalAlpha >= .95) 
                this.plotLabel(canvas, node, opt);
            else 
                this.hideLabel(node, false);
        } else {
            this.hideLabel(node, true);
        }
    },
    
    /* 
      Method: placeLabel

      Overrides abstract method placeLabel in <Graph.Plot>.

      Parameters:

      tag - A DOM label element.
      node - A <Graph.Node>.
      controller - A configuration/controller object passed to the visualization.
     
    */
    placeLabel: function(tag, node, controller) {
        var pos = node.pos.getc(true), dim = this.node, canvas = this.viz.canvas;
        var w = dim.overridable && node.data.$width || dim.width;
        var h = dim.overridable && node.data.$height || dim.height;
        var radius = canvas.getSize();
        if(dim.align == "center") {
            var labelPos= {
                x: Math.round(pos.x - w / 2 + radius.width/2),
                y: Math.round(pos.y - h / 2 + radius.height/2)
            };
        } else if (dim.align == "left") {
            var orn = this.config.orientation;
            if(orn == "bottom" || orn == "top") {
                var labelPos= {
                    x: Math.round(pos.x - w / 2 + radius.width/2),
                    y: Math.round(pos.y + radius.height/2)
                };
            } else {
                var labelPos= {
                    x: Math.round(pos.x + radius.width/2),
                    y: Math.round(pos.y - h / 2 + radius.height/2)
                };
            }
        } else if(dim.align == "right") {
            var orn = this.config.orientation;
            if(orn == "bottom" || orn == "top") {
                var labelPos= {
                    x: Math.round(pos.x - w / 2 + radius.width/2),
                    y: Math.round(pos.y - h + radius.height/2)
                };
            } else {
                var labelPos= {
                    x: Math.round(pos.x - w + radius.width/2),
                    y: Math.round(pos.y - h / 2 + radius.height/2)
                };
            }
        } else throw "align: not implemented";

        var style = tag.style;
        style.left = labelPos.x + 'px';
        style.top  = labelPos.y + 'px';
        style.display = this.fitsInCanvas(labelPos, canvas)? '' : 'none';
        controller.onPlaceLabel(tag, node);
    },
    
    
    getAlignedPos: function(pos, width, height) {
        var nconfig = this.node;
        if(nconfig.align == "center") {
            var square = {
                x: pos.x - width / 2,
                y: pos.y - height / 2
            };
        } else if (nconfig.align == "left") {
            var orn = this.config.orientation;
            if(orn == "bottom" || orn == "top") {
                var square = {
                    x: pos.x - width / 2,
                    y: pos.y
                };
            } else {
                var square = {
                    x: pos.x,
                    y: pos.y - height / 2
                };
            }
        } else if(nconfig.align == "right") {
            var orn = this.config.orientation;
            if(orn == "bottom" || orn == "top") {
                var square = {
                    x: pos.x - width / 2,
                    y: pos.y - height
                };
            } else {
                var square = {
                    x: pos.x - width,
                    y: pos.y - height / 2
                };
            }
        } else throw "align: not implemented";
        
        return square;
    }
});

/*
  Class: ST.Plot.NodeTypes

  Here are implemented all kinds of node rendering functions. 
  Rendering functions implemented are 'none', 'circle', 'ellipse', 'rectangle' and 'square'.

  You can add new Node types by implementing a new method in this class

  Example:

  (start code js)
    ST.Plot.NodeTypes.implement({
      'newnodetypename': function(node, canvas) {
        //Render my node here.
      }
    });
  (end code)

*/
ST.Plot.NodeTypes = new Class({
    'none': function() {},
    
    'circle': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var cond = nconfig.overridable && data;
        var dim  = cond && data.$dim || nconfig.dim;
        var algnPos = this.getAlignedPos(pos, dim * 2, dim * 2);
        canvas.path('fill', function(context) {
            context.arc(algnPos.x + dim, algnPos.y + dim, dim, 0, Math.PI * 2, true);            
        });
    },

    'square': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var cond = nconfig.overridable && data;
        var dim  = cond && data.$dim || nconfig.dim;
        var algnPos = this.getAlignedPos(pos, dim, dim);
        canvas.getCtx().fillRect(algnPos.x, algnPos.y, dim, dim);
    },

    'ellipse': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var cond = nconfig.overridable && data;
        var width  = (cond && data.$width || nconfig.width) / 2;
        var height = (cond && data.$height || nconfig.height) / 2;
        var algnPos = this.getAlignedPos(pos, width * 2, height * 2);
        var ctx = canvas.getCtx();
        ctx.save();
        ctx.scale(width / height, height / width);
        canvas.path('fill', function(context) {
            context.arc((algnPos.x + width) * (height / width), (algnPos.y + height) * (width / height), height, 0, Math.PI * 2, true);            
        });
        ctx.restore();
    },

    'rectangle': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var cond = nconfig.overridable && data;
        var width  = cond && data.$width || nconfig.width;
        var height = cond && data.$height || nconfig.height;
        var algnPos = this.getAlignedPos(pos, width, height);
        canvas.getCtx().fillRect(algnPos.x, algnPos.y, width, height);
    }
});

/*
  Class: ST.Plot.EdgeTypes

  Here are implemented all kinds of edge rendering functions. 
  Rendering functions implemented are 'none', 'line', 'quadratic:begin', 'quadratic:end', 'bezier' and 'arrow'.

  You can add new Edge types by implementing a new method in this class

  Example:

  (start code js)
    ST.Plot.EdgeTypes.implement({
      'newedgetypename': function(adj, canvas) {
        //Render my edge here.
      }
    });
  (end code)

*/
ST.Plot.EdgeTypes = new Class({
    'none': function() {},
    
    'line': function(adj, canvas) {
        var begin = this.viz.geom.getEdge(adj.nodeFrom, 'begin');
        var end =  this.viz.geom.getEdge(adj.nodeTo, 'end');
        canvas.path('stroke', function(ctx) {
            ctx.moveTo(begin.x, begin.y);
            ctx.lineTo(end.x, end.y);
        });
    },
    
    'quadratic:begin': function(adj, canvas) {
        var orn = this.config.orientation;
        var data = adj.data, econfig = this.edge;
        var begin = this.viz.geom.getEdge(adj.nodeFrom, 'begin');
        var end =  this.viz.geom.getEdge(adj.nodeTo, 'end');
        var cond = econfig.overridable && data;
        var dim = cond && data.$dim || econfig.dim;
        switch(orn) {
            case "left":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(begin.x + dim, begin.y, end.x, end.y);
                });
                break;
            case "right":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(begin.x - dim, begin.y, end.x, end.y);
                });
                break;
            case "top":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(begin.x, begin.y + dim, end.x, end.y);
                });
                break;
            case "bottom":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(begin.x, begin.y - dim, end.x, end.y);
                });
                break;
        }
    },

    'quadratic:end': function(adj, canvas) {
        var orn = this.config.orientation;
        var data = adj.data, econfig = this.edge;
        var begin = this.viz.geom.getEdge(adj.nodeFrom, 'begin');
        var end =  this.viz.geom.getEdge(adj.nodeTo, 'end');
        var cond = econfig.overridable && data;
        var dim = cond && data.$dim || econfig.dim;
        switch(orn) {
            case "left":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(end.x - dim, end.y, end.x, end.y);
                });
                break;
            case "right":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(end.x + dim, end.y, end.x, end.y);
                });
                break;
            case "top":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(end.x, end.y - dim, end.x, end.y);
                });
                break;
            case "bottom":
                canvas.path('stroke', function(ctx){
                    ctx.moveTo(begin.x, begin.y);
                    ctx.quadraticCurveTo(end.x, end.y + dim, end.x, end.y);
                });
                break;
        }
    },

    'bezier': function(adj, canvas) {
        var data = adj.data, econfig = this.edge, orn = this.config.orientation;
        var begin = this.viz.geom.getEdge(adj.nodeFrom, 'begin');
        var end =  this.viz.geom.getEdge(adj.nodeTo, 'end');
        var cond = econfig.overridable && data;
        var dim = cond && data.$dim || econfig.dim;
        switch(orn) {
            case "left":
                canvas.path('stroke', function(ctx) {
                    ctx.moveTo(begin.x, begin.y);
                    ctx.bezierCurveTo(begin.x + dim, begin.y, end.x - dim, end.y, end.x, end.y);
                });
                break;
            case "right":
                canvas.path('stroke', function(ctx) {
                    ctx.moveTo(begin.x, begin.y);
                    ctx.bezierCurveTo(begin.x - dim, begin.y, end.x + dim, end.y, end.x, end.y);
                });
                break;
            case "top":
                canvas.path('stroke', function(ctx) {
                    ctx.moveTo(begin.x, begin.y);
                    ctx.bezierCurveTo(begin.x, begin.y + dim, end.x, end.y - dim, end.x, end.y);
                });
                break;
            case "bottom":
                canvas.path('stroke', function(ctx) {
                    ctx.moveTo(begin.x, begin.y);
                    ctx.bezierCurveTo(begin.x, begin.y - dim, end.x, end.y + dim, end.x, end.y);
                });
                break;
        }
    },

    'arrow': function(adj, canvas) {
        var node = adj.nodeFrom, child = adj.nodeTo;
        var data = adj.data, econfig = this.edge;
        //get edge dim
        var cond = econfig.overridable && data;
        var edgeDim = cond && data.$dim || econfig.dim;
        //get edge direction
        if(cond && data.$direction && data.$direction.length > 1) {
            var nodeHash = {};
            nodeHash[node.id] = node;
            nodeHash[child.id] = child;
            var sense = data.$direction;
            node = nodeHash[sense[0]];
            child = nodeHash[sense[1]];
        }
        var posFrom = this.viz.geom.getEdge(node, 'begin');
        var posTo =  this.viz.geom.getEdge(child, 'end');
        var vect = new Complex(posTo.x - posFrom.x, posTo.y - posFrom.y);
        vect.$scale(edgeDim / vect.norm());
        var intermediatePoint = new Complex(posTo.x - vect.x, posTo.y - vect.y);
        var normal = new Complex(-vect.y / 2, vect.x / 2);
        var v1 = intermediatePoint.add(normal), v2 = intermediatePoint.$add(normal.$scale(-1));
        canvas.path('stroke', function(context) {
            context.moveTo(posFrom.x, posFrom.y);
            context.lineTo(posTo.x, posTo.y);
        });
        canvas.path('fill', function(context) {
            context.moveTo(v1.x, v1.y);
            context.lineTo(v2.x, v2.y);
            context.lineTo(posTo.x, posTo.y);
        });
    }
});


/*
 * File: AngularWidth.js
 * 
 * Provides utility methods for calculating angular widths.
 *
 * Implemented by:
 *
 * <RGraph>, <Hypertree>
 *
 */

/*
   Object: AngularWidth

   Provides utility methods for calculating angular widths.
*/
var AngularWidth = {
    /*
     Method: setAngularWidthForNodes
    
     Sets nodes angular widths.
    */
    setAngularWidthForNodes: function() {
        var config = this.config.Node;
		var overridable = config.overridable;
		var dim = config.dim;
        
		Graph.Util.eachBFS(this.graph, this.root, function(elem, i) {
            var diamValue = (overridable 
			 && elem.data 
			 && elem.data.$aw) || dim;
            elem._angularWidth = diamValue / i;
        }, "ignore");
    },
    
    /*
     Method: setSubtreesAngularWidth
    
     Sets subtrees angular widths.
    */
    setSubtreesAngularWidth: function() {
        var that = this;
        Graph.Util.eachNode(this.graph, function(elem) {
            that.setSubtreeAngularWidth(elem);
        }, "ignore");
    },
    
    /*
     Method: setSubtreeAngularWidth
    
     Sets the angular width for a subtree.
    */
    setSubtreeAngularWidth: function(elem) {
        var that = this, nodeAW = elem._angularWidth, sumAW = 0;
        Graph.Util.eachSubnode(elem, function(child) {
            that.setSubtreeAngularWidth(child);
            sumAW += child._treeAngularWidth;
        }, "ignore");
        elem._treeAngularWidth = Math.max(nodeAW, sumAW);
    },
    
    /*
     Method: computeAngularWidths
    
     Computes nodes and subtrees angular widths.
    */
    computeAngularWidths: function () {
        this.setAngularWidthForNodes();
        this.setSubtreesAngularWidth();
    }
	
};


/*
 * File: RGraph.js
 * 
 * Implements the <RGraph> class and other derived classes.
 *
 * Description:
 *
 * A radial layout of a tree puts the root node on the center of the canvas, places its children on the first concentric ring away from the root node, its grandchildren on a second concentric ring, and so on...
 *
 * Ka-Ping Yee, Danyel Fisher, Rachna Dhamija and Marti Hearst introduced a very interesting paper called "Animated Exploration of Dynamic Graphs with Radial Layout". In this paper they describe a way to animate a radial layout of a tree with ease-in and ease-out transitions, which make transitions from a graph's state to another easier to understand for the viewer.
 *
 * Inspired by:
 *
 * Animated Exploration of Dynamic Graphs with Radial Layout (Ka-Ping Yee, Danyel Fisher, Rachna Dhamija, Marti Hearst)
 *
 * <http://bailando.sims.berkeley.edu/papers/infovis01.htm>
 *
 * Disclaimer:
 *
 * This visualization was built from scratch, taking only the paper as inspiration, and only shares some features with this paper.
 *
 * 
 */

/*
   Class: RGraph
      
     The main RGraph class

     Extends:

     <Loader>, <AngularWidth>

     Parameters:

     canvas - A <Canvas> Class
     config - A configuration/controller object.

     Configuration:
    
     The configuration object can have the following properties (all properties are optional and have a default value)
     
     *General*

     - _interpolation_ Interpolation type used for animations. Possible options are 'polar' and 'linear'. Default's 'linear'.
     - _levelDistance_ Distance between a parent node and its children. Default's 100.
     - _withLabels_ Whether the visualization should use/create labels or not. Default's *true*.

     *Node*
     
     Customize the visualization nodes' shape, color, and other style properties.

     - _Node_

     This object has as properties

     - _overridable_ Determine whether or not nodes properties can be overriden by a particular node. Default's false.

     If given a JSON tree or graph, a node _data_ property contains properties which are the same as defined here but prefixed with 
     a dollar sign (i.e $), the node properties will override the global node properties.

     - _type_ Node type (shape). Possible options are "none", "square", "rectangle", "circle", "triangle", "star". Default's "circle".
     - _color_ Node color. Default's '#ccb'.
     - _lineWidth_ Line width. If nodes aren't drawn with strokes then this property won't be of any use. Default's 1.
     - _height_ Node height. Used for plotting rectangular nodes. Default's 5.
     - _width_ Node width. Used for plotting rectangular nodes. Default's 5.
     - _dim_ An extra parameter used by other complex shapes such as square and circle to determine the shape's diameter. Default's 3.

     *Edge*

     Customize the visualization edges' shape, color, and other style properties.

     - _Edge_

     This object has as properties

     - _overridable_ Determine whether or not edges properties can be overriden by a particular edge object. Default's false.

     If given a JSON _complex_ graph (defined in <Loader.loadJSON>), an adjacency _data_ property contains properties which are the same as defined here but prefixed with 
     a dollar sign (i.e $), the adjacency properties will override the global edge properties.

     - _type_ Edge type (shape). Possible options are "none", "line" and "arrow". Default's "line".
     - _color_ Edge color. Default's '#ccb'.
     - _lineWidth_ Line width. If edges aren't drawn with strokes then this property won't be of any use. Default's 1.

     *Animations*

     - _duration_ Duration of the animation in milliseconds. Default's 2500.
     - _fps_ Frames per second. Default's 40.
     - _transition_ One of the transitions defined in the <Animation> class. Default's Quart.easeInOut.
     - _clearCanvas_ Whether to clear canvas on each animation frame or not. Default's true.
     
    *Controller options*

    You can also implement controller functions inside the configuration object. This functions are
    
    - _onBeforeCompute(node)_ This method is called right before performing all computation and animations to the JIT visualization.
    - _onAfterCompute()_ This method is triggered right after all animations or computations for the JIT visualizations ended.
    - _onCreateLabel(domElement, node)_ This method receives the label dom element as first parameter, and the corresponding <Graph.Node> as second parameter. This method will only be called on label creation. Note that a <Graph.Node> is a node from the input tree/graph you provided to the visualization. If you want to know more about what kind of JSON tree/graph format is used to feed the visualizations, you can take a look at <Loader.loadJSON>. This method proves useful when adding events to the labels used by the JIT.
    - _onPlaceLabel(domElement, node)_ This method receives the label dom element as first parameter and the corresponding <Graph.Node> as second parameter. This method is called each time a label has been placed on the visualization, and thus it allows you to update the labels properties, such as size or position. Note that onPlaceLabel will be triggered after updating the labels positions. That means that, for example, the left and top css properties are already updated to match the nodes positions.
    - _onBeforePlotNode(node)_ This method is triggered right before plotting a given node. The _node_ parameter is the <Graph.Node> to be plotted. 
This method is useful for changing a node style right before plotting it.
    - _onAfterPlotNode(node)_ This method is triggered right after plotting a given node. The _node_ parameter is the <Graph.Node> plotted.
    - _onBeforePlotLine(adj)_ This method is triggered right before plotting an edge. The _adj_ parameter is a <Graph.Adjacence> object. 
This method is useful for adding some styles to a particular edge before being plotted.
    - _onAfterPlotLine(adj)_ This method is triggered right after plotting an edge. The _adj_ parameter is the <Graph.Adjacence> plotted.

    Example:

    Here goes a complete example. In most cases you won't be forced to implement all properties and methods. In fact, 
    all configuration properties  have the default value assigned.

    I won't be instanciating a <Canvas> class here. If you want to know more about instanciating a <Canvas> class 
    please take a look at the <Canvas> class documentation.

    (start code js)
      var rgraph = new RGraph(canvas, {
        interpolation: 'linear',
        levelDistance: 100,
        withLabels: true,
        Node: {
          overridable: false,
          type: 'circle',
          color: '#ccb',
          lineWidth: 1,
          height: 5,
          width: 5,
          dim: 3
        },
        Edge: {
          overridable: false,
          type: 'line',
          color: '#ccb',
          lineWidth: 1
        },
        duration: 2500,
        fps: 40,
        transition: Trans.Quart.easeInOut,
        clearCanvas: true,
        onBeforeCompute: function(node) {
          //do something onBeforeCompute
        },
        onAfterCompute:  function () {
          //do something onAfterCompute
        },
        onCreateLabel:   function(domElement, node) {
          //do something onCreateLabel
        },
        onPlaceLabel:    function(domElement, node) {
          //do something onPlaceLabel
        },
        onBeforePlotNode:function(node) {
          //do something onBeforePlotNode
        },
        onAfterPlotNode: function(node) {
          //do something onAfterPlotNode
        },
        onBeforePlotLine:function(adj) {
          //do something onBeforePlotLine
        },
        onAfterPlotLine: function(adj) {
          //do something onAfterPlotLine
        }
      });
    (end code)

  Instance Properties:

   - _graph_ Access a <Graph> instance.
   - _op_ Access a <RGraph.Op> instance.
   - _fx_ Access a <RGraph.Plot> instance.
*/

this.RGraph = new Class({
	
    Implements: [Loader, AngularWidth],
    
	initialize: function(canvas, controller) {
		var config= {
		        labelContainer: canvas.id + '-label',

                interpolation: 'linear',
		        levelDistance: 100,
		        withLabels: true,
                
				Node: {
					overridable: false,
				    type: 'circle',
					dim: 3,
					color: '#ccb',
                    width: 5,
                    height: 5,   
					lineWidth: 1
				},
				
				Edge: {
					overridable: false,
				    type: 'line',
					color: '#ccb',
					lineWidth: 1
				},

		        fps:40,
		        duration: 2500,
                transition: Trans.Quart.easeInOut,
                clearCanvas: true
		};

	    var innerController = {
	        onBeforeCompute: $empty,
	        onAfterCompute:  $empty,
	        onCreateLabel:   $empty,
	        onPlaceLabel:    $empty,
	        onComplete:      $empty,
	        onBeforePlotLine:$empty,
	        onAfterPlotLine: $empty,
	        onBeforePlotNode:$empty,
	        onAfterPlotNode: $empty
	    };
		
	    this.controller = this.config = $merge(config, innerController, controller);
	    this.graphOptions = {
            'complex': false,
            'Node': {
                'selected': false,
                'exist': true,
                'drawn': true
            }
        };
		this.graph = new Graph(this.graphOptions);
	    this.fx = new RGraph.Plot(this);
		this.op = new RGraph.Op(this);
		this.json = null;
	    this.canvas = canvas;
	    this.root = null;
	    this.busy = false;
	    this.parent = false;
	},
    /* 
     Method: refresh 
     
     Computes nodes' positions and replots the tree.

    */ 
    refresh: function() {
        this.compute();
        this.plot();
    },
    
    /*
     Method: reposition
    
     An alias for computing new positions to _endPos_

     See also:

     <RGraph.compute>
     
    */
    reposition: function() {
        this.compute('endPos');
    },


    /*
     Method: plot
    
     Plots the RGraph
    */
    plot: function() {
        this.fx.plot();
    },
    /* 
     Method: compute 
     
     Computes nodes' positions. 

     Parameters:

     property - _optional_ A <Graph.Node> position property to store the new positions. Possible values are 'pos', 'endPos' or 'startPos'.

    */ 
    compute: function(property) {
        var prop = property || ['pos', 'startPos', 'endPos'];
        var node = this.graph.getNode(this.root);
        node._depth = 0;
        Graph.Util.computeLevels(this.graph, this.root, 0, "ignore");
        this.computeAngularWidths();
        this.computePositions(prop);
    },
    
    /*
     computePositions
    
     Performs the main algorithm for computing node positions.
    */
    computePositions: function(property) {
        var propArray = $splat(property);
        var aGraph = this.graph;
        var GUtil = Graph.Util;
        var root = this.graph.getNode(this.root);
        var parent = this.parent;
		var config = this.config;

        for(var i=0; i<propArray.length; i++)
            root[propArray[i]] = $P(0, 0);
        
        root.angleSpan = {
            begin: 0,
            end: 2 * Math.PI
        };
        root._rel = 1;
        
        GUtil.eachBFS(this.graph, this.root, function (elem) {
            var angleSpan = elem.angleSpan.end - elem.angleSpan.begin;
            var rho = (elem._depth + 1) * config.levelDistance;
            var angleInit = elem.angleSpan.begin;
            
			var totalAngularWidths = 0, subnodes = [];
            GUtil.eachSubnode(elem, function(sib) {
                totalAngularWidths += sib._treeAngularWidth;
				subnodes.push(sib);
            }, "ignore");
            
            if(parent && parent.id == elem.id && subnodes.length > 0 && subnodes[0].dist) {
                subnodes.sort(function(a, b) {
                    return  (a.dist >= b.dist) - (a.dist <= b.dist);
                });
            }
            for(var k=0; k < subnodes.length; k++) {
                var child = subnodes[k];
                if(!child._flag) {
                    child._rel = child._treeAngularWidth / totalAngularWidths;
                    var angleProportion = child._rel * angleSpan;
                    var theta = angleInit + angleProportion / 2;

                    for(var i=0; i<propArray.length; i++)
                        child[propArray[i]] = $P(theta, rho);

                    child.angleSpan = {
                        begin: angleInit,
                        end: angleInit + angleProportion
                    };
                    angleInit += angleProportion;
                }
            }
        }, "ignore");
    },

    /*
     getNodeAndParentAngle
    
     Returns the _parent_ of the given node, also calculating its angle span.
    */
    getNodeAndParentAngle: function(id) {
        var theta = false;
        var n  = this.graph.getNode(id);
        var ps = Graph.Util.getParents(n);
        var p  = (ps.length > 0)? ps[0] : false;
        if(p) {
            var posParent = p.pos.getc(), posChild = n.pos.getc();
            var newPos    = posParent.add(posChild.scale(-1));
            theta = Math.atan2(newPos.y, newPos.x);
            if(theta < 0) theta += 2 * Math.PI;
        }
        return {parent: p, theta: theta};
    },
    
    /*
     tagChildren
    
     Enumerates the children in order to mantain child ordering (second constraint of the paper).
    */
    tagChildren: function(par, id) {
        if(par.angleSpan) {
          var adjs = [];
          Graph.Util.eachAdjacency(par, function(elem) {
            adjs.push(elem.nodeTo);
          }, "ignore");
          var len = adjs.length;
          for(var i=0; i < len && id != adjs[i].id; i++);
          for(var j= (i+1) % len, k = 0; id !=  adjs[j].id; j = (j+1) % len) {
            adjs[j].dist = k++;
          }
        }
    },
    
     /* 
     Method: onClick 
     
     Performs all calculations and animations to center the node specified by _id_.

     Parameters:

     id - A <Graph.Node> id.
     opt - _optional_ An object containing some extra properties like

     - _hideLabels_ Hide labels when performing the animation. Default's *true*.

     Example:

     (start code js)
       rgraph.onClick('someid');
       //or also...
       rgraph.onClick('someid', {
        hideLabels: false
       });
      (end code)
      
    */ 
    onClick: function(id, opt) {
        if(this.root != id && !this.busy) {
            this.busy = true;
            this.root = id, that = this;
            this.controller.onBeforeCompute(this.graph.getNode(id));
            var obj = this.getNodeAndParentAngle(id);
            
			//second constraint
			this.tagChildren(obj.parent, id);
            this.parent = obj.parent;
            this.compute('endPos');
            
            //first constraint
            var thetaDiff = obj.theta - obj.parent.endPos.theta;
            Graph.Util.eachNode(this.graph, function(elem) {
                elem.endPos.set(elem.endPos.getp().add($P(thetaDiff, 0)));
            });

            var mode = this.config.interpolation;
            opt = $merge({ onComplete: $empty }, opt || {});

			this.fx.animate($merge({
                hideLabels: true,
                modes: [mode]
            }, opt, {
                onComplete: function() {
                    that.busy = false;
                    opt.onComplete();
                }
            }));
        }       
    }
});

/*
   Class: RGraph.Op

   Performs advanced operations on trees and graphs.

   Extends:

   All <Graph.Op> methods

   Access:

   This instance can be accessed with the _op_ parameter of the <RGraph> instance created.

   Example:

   (start code js)
    var rgraph = new RGraph(canvas, config);
    rgraph.op.morph //or can also call any other <Graph.Op> method
   (end code)
   
*/
RGraph.Op = new Class({

    Implements: Graph.Op,

    initialize: function(viz) {
        this.viz = viz;
    }
});

/*
   Class: RGraph.Plot

   Performs plotting operations.

   Extends:

   All <Graph.Plot> methods

   Access:

   This instance can be accessed with the _fx_ parameter of the <RGraph> instance created.

   Example:

   (start code js)
    var rgraph = new RGraph(canvas, config);
    rgraph.fx.placeLabel //or can also call any other <RGraph.Plot> method
   (end code)

*/
RGraph.Plot = new Class({
	
	Implements: Graph.Plot,
	
    initialize: function(viz) {
        this.viz = viz;
		this.config = viz.config;
		this.node = viz.config.Node;
		this.edge = viz.config.Edge;
		this.animation = new Animation;
	    this.nodeTypes = new RGraph.Plot.NodeTypes;
		this.edgeTypes = new RGraph.Plot.EdgeTypes;
    },

    /* 
      Method: placeLabel

      Overrides abstract method placeLabel in <Graph.Plot>.

      Parameters:

      tag - A DOM label element.
      node - A <Graph.Node>.
      controller - A configuration/controller object passed to the visualization.
     
     */
    placeLabel: function(tag, node, controller) {
        var pos = node.pos.getc(true), canvas = this.viz.canvas; 
        var radius= canvas.getSize();
        var labelPos= {
            x: Math.round(pos.x + radius.width/2),
            y: Math.round(pos.y + radius.height/2)
        };
        var style = tag.style;
        style.left = labelPos.x + 'px';
        style.top  = labelPos.y + 'px';
        style.display = this.fitsInCanvas(labelPos, canvas)? '' : 'none';
        controller.onPlaceLabel(tag, node);
	}
});

/*
  Class: RGraph.Plot.NodeTypes

  Here are implemented all kinds of node rendering functions. 
  Rendering functions implemented are 'none', 'circle', 'triangle', 'rectangle', 'star' and 'square'.

  You can add new Node types by implementing a new method in this class

  Example:

  (start code js)
    RGraph.Plot.NodeTypes.implement({
      'newnodetypename': function(node, canvas) {
        //Render my node here.
      }
    });
  (end code)

*/
RGraph.Plot.NodeTypes = new Class({
    'none': function() {},
    
    'circle': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim;
        canvas.path('fill', function(context) {
            context.arc(pos.x, pos.y, nodeDim, 0, Math.PI*2, true);            
        });
    },
    
    'square': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim;
		var nodeDim2 = 2 * nodeDim;
        canvas.getCtx().fillRect(pos.x - nodeDim, pos.y - nodeDim, nodeDim2, nodeDim2);
    },
    
    'rectangle': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var width = nconfig.overridable && data && data.$width || nconfig.width;
		var height = nconfig.overridable && data && data.$height || nconfig.height;
        canvas.getCtx().fillRect(pos.x - width / 2, pos.y - height / 2, width, height);
    },
    
    'triangle': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim;
        var c1x = pos.x, c1y = pos.y - nodeDim,
        c2x = c1x - nodeDim, c2y = pos.y + nodeDim,
        c3x = c1x + nodeDim, c3y = c2y;
        canvas.path('fill', function(ctx) {
            ctx.moveTo(c1x, c1y);
            ctx.lineTo(c2x, c2y);
            ctx.lineTo(c3x, c3y);
        });
    },
    
    'star': function(node, canvas) {
        var pos = node.pos.getc(true), nconfig = this.node, data = node.data;
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim;
        var ctx = canvas.getCtx(), pi5 = Math.PI / 5;
        ctx.save();
        ctx.translate(pos.x, pos.y);
        ctx.beginPath();
        ctx.moveTo(nodeDim, 0);
        for (var i=0; i<9; i++){
          ctx.rotate(pi5);
          if(i % 2 == 0) {
            ctx.lineTo((nodeDim / 0.525731) * 0.200811, 0);
          } else {
            ctx.lineTo(nodeDim, 0);
          }
        }
        ctx.closePath();
        ctx.fill();
        ctx.restore();
    }
});

/*
  Class: RGraph.Plot.EdgeTypes

  Here are implemented all kinds of edge rendering functions. 
  Rendering functions implemented are 'none', 'line' and 'arrow'.

  You can add new Edge types by implementing a new method in this class

  Example:

  (start code js)
    RGraph.Plot.EdgeTypes.implement({
      'newedgetypename': function(adj, canvas) {
        //Render my edge here.
      }
    });
  (end code)

*/
RGraph.Plot.EdgeTypes = new Class({
    'none': function() {},
    
    'line': function(adj, canvas) {
        var pos = adj.nodeFrom.pos.getc(true);
		var posChild = adj.nodeTo.pos.getc(true);
        canvas.path('stroke', function(context) {
            context.moveTo(pos.x, pos.y);
            context.lineTo(posChild.x, posChild.y);
        });
    },
    
    'arrow': function(adj, canvas) {
        var node = adj.nodeFrom, child = adj.nodeTo;
		var data = adj.data, econfig = this.edge;
        //get edge dim
		var cond = econfig.overridable && data;
		var edgeDim = cond && data.$dim || 14;
        //get edge direction
        if(cond && data.$direction && data.$direction.length > 1) {
            var nodeHash = {};
            nodeHash[node.id] = node;
            nodeHash[child.id] = child;
            var sense = data.$direction;
            node = nodeHash[sense[0]];
            child = nodeHash[sense[1]];
        }
        var posFrom = node.pos.getc(true), posTo = child.pos.getc(true);
        var vect = new Complex(posTo.x - posFrom.x, posTo.y - posFrom.y);
        vect.$scale(edgeDim / vect.norm());
        var intermediatePoint = new Complex(posTo.x - vect.x, posTo.y - vect.y);
        var normal = new Complex(-vect.y / 2, vect.x / 2);
        var v1 = intermediatePoint.add(normal), v2 = intermediatePoint.$add(normal.$scale(-1));
        canvas.path('stroke', function(context) {
            context.moveTo(posFrom.x, posFrom.y);
            context.lineTo(posTo.x, posTo.y);
        });
		canvas.path('fill', function(context) {
            context.moveTo(v1.x, v1.y);
            context.lineTo(v2.x, v2.y);
            context.lineTo(posTo.x, posTo.y);
        });
	}
});


/*
 * File: Hypertree.js
 * 
 * Implements the <Hypertree> class and other derived classes.
 *
 * Description:
 *
 * A Hyperbolic Tree (HT) is a focus+context information visualization technique used to display large amount of inter-related data. This technique was originally developed at Xerox PARC.
 *
 * The HT algorithm plots a tree in what's called the Poincare Disk model of Hyperbolic Geometry, a kind of non-Euclidean geometry. By doing this, the HT algorithm applies a moebius transformation to the tree in order to display it with a magnifying glass effect.
 *
 * Inspired by:
 *
 * A Focus+Context Technique Based on Hyperbolic Geometry for Visualizing Large Hierarchies (John Lamping, Ramana Rao, and Peter Pirolli).
 *
 * <http://www.cs.tau.ac.il/~asharf/shrek/Projects/HypBrowser/startree-chi95.pdf>
 *
 * Disclaimer:
 *
 * This visualization was built from scratch, taking only the paper as inspiration, and only shares some features with the Hypertree.
 *

*/

/* 
     Complex 
     
     A multi-purpose Complex Class with common methods. Exetended for the Hypertree. 
 
*/ 
/* 
   moebiusTransformation 
 
   Calculates a moebius transformation for this point / complex. 
    For more information go to: 
        http://en.wikipedia.org/wiki/Moebius_transformation. 
 
   Parameters: 
 
      c - An initialized Complex instance representing a translation Vector. 
*/ 
 
Complex.prototype.moebiusTransformation = function(c) { 
		var num = this.add(c); 
		var den = c.$conjugate().$prod(this); den.x++; 
		return num.$div(den); 
}; 
 
/* 
   Method: getClosestNodeToOrigin 
 
   Extends <Graph.Util>. Returns the closest node to the center of canvas.

   Parameters:
  
    graph - A <Graph> instance.
    prop - _optional_ a <Graph.Node> position property. Possible properties are 'startPos', 'pos' or 'endPos'. Default's 'pos'.

   Returns:

    Closest node to origin. Returns *null* otherwise.
  
*/ 
Graph.Util.getClosestNodeToOrigin = function(graph, prop, flags) { 
    return this.getClosestNodeToPos(graph, Polar.KER, prop, flags);
}; 

/* 
   Method: getClosestNodeToPos
 
   Extends <Graph.Util>. Returns the closest node to the given position.

   Parameters:
  
    graph - A <Graph> instance.
    p[os - A <Complex> or <Polar> instance.
    prop - _optional_ a <Graph.Node> position property. Possible properties are 'startPos', 'pos' or 'endPos'. Default's 'pos'.

   Returns:

    Closest node to the given position. Returns *null* otherwise.
  
*/ 
Graph.Util.getClosestNodeToPos = function(graph, pos, prop, flags) { 
  var node = null; prop = prop || 'pos'; pos = pos && pos.getc(true) || Complex.KER;
  var distance = function(a, b) { 
    var d1 = a.x - b.x, d2 = a.y - b.y;
    return d1 * d1 + d2 * d2;
  };
  this.eachNode(graph, function(elem) { 
    node = (node == null || distance(elem[prop].getc(true), pos) < distance(node[prop].getc(true), pos))? elem : node; 
  }, flags); 
  return node; 
}; 

/* 
    moebiusTransformation 
     
    Calculates a moebius transformation for the hyperbolic tree. 
     
    <http://en.wikipedia.org/wiki/Moebius_transformation> 
      
     Parameters: 
     
        graph - A <Graph> instance.
        pos - A <Complex>.
        prop - A property array.
        theta - Rotation angle. 
        startPos - _optional_ start position. 
*/   
Graph.Util.moebiusTransformation = function(graph, pos, prop, startPos, flags) { 
    this.eachNode(graph, function(elem) { 
        for(var i=0; i<prop.length; i++) { 
            var p = pos[i].scale(-1), property = startPos? startPos : prop[i];  
            elem[prop[i]].set(elem[property].getc().moebiusTransformation(p)); 
        } 
    }, flags); 
}; 
 
/* 
   Class: Hypertree 
      
     The main Hypertree class

     Extends:

     <Loader>, <AngularWidth>

     Parameters:

     canvas - A <Canvas> Class
     config - A configuration/controller object.

     Configuration:
    
     The configuration object can have the following properties (all properties are optional and have a default value)
      
     *General*
     - _withLabels_ Whether the visualization should use/create labels or not. Default's *true*.
     
     *Node*
     
     Customize the visualization nodes' shape, color, and other style properties.

     - _Node_

     This object has as properties

     - _overridable_ Determine whether or not nodes properties can be overriden by a particular node. Default's false.

     If given a JSON tree or graph, a node _data_ property contains properties which are the same as defined here but prefixed with 
     a dollar sign (i.e $), the node properties will override the global node properties.

     - _type_ Node type (shape). Possible options are "none", "square", "rectangle", "circle", "triangle", "star". Default's "circle".
     - _color_ Node color. Default's '#ccb'.
     - _lineWidth_ Line width. If nodes aren't drawn with strokes then this property won't be of any use. Default's 1.
     - _height_ Node height. Used for plotting rectangular nodes. Default's 5.
     - _width_ Node width. Used for plotting rectangular nodes. Default's 5.
     - _dim_ An extra parameter used by other complex shapes such as square and circle to determine the shape's diameter. Default's 7.
     - _transform_ Whether to apply the moebius transformation to the nodes or not. Default's true.

     *Edge*

     Customize the visualization edges' shape, color, and other style properties.

     - _Edge_

     This object has as properties

     - _overridable_ Determine whether or not edges properties can be overriden by a particular edge object. Default's false.

     If given a JSON _complex_ graph (defined in <Loader.loadJSON>), an adjacency _data_ property contains properties which are the same as defined here but prefixed with 
     a dollar sign (i.e $), the adjacency properties will override the global edge properties.

     - _type_ Edge type (shape). Possible options are "none", "line" and "hyperline". Default's "hyperline".
     - _color_ Edge color. Default's '#ccb'.
     - _lineWidth_ Line width. If edges aren't drawn with strokes then this property won't be of any use. Default's 1.

     *Animations*

     - _duration_ Duration of the animation in milliseconds. Default's 1500.
     - _fps_ Frames per second. Default's 40.
     - _transition_ One of the transitions defined in the <Animation> class. Default's Quart.easeInOut.
     - _clearCanvas_ Whether to clear canvas on each animation frame or not. Default's true.

    *Controller options*

    You can also implement controller functions inside the configuration object. This functions are
    
    - _onBeforeCompute(node)_ This method is called right before performing all computation and animations to the JIT visualization.
    - _onAfterCompute()_ This method is triggered right after all animations or computations for the JIT visualizations ended.
    - _onCreateLabel(domElement, node)_ This method receives the label dom element as first parameter, and the corresponding <Graph.Node> as second parameter. This method will only be called on label creation. Note that a <Graph.Node> is a node from the input tree/graph you provided to the visualization. If you want to know more about what kind of JSON tree/graph format is used to feed the visualizations, you can take a look at <Loader.loadJSON>. This method proves useful when adding events to the labels used by the JIT.
    - _onPlaceLabel(domElement, node)_ This method receives the label dom element as first parameter and the corresponding <Graph.Node> as second parameter. This method is called each time a label has been placed on the visualization, and thus it allows you to update the labels properties, such as size or position. Note that onPlaceLabel will be triggered after updating the labels positions. That means that, for example, the left and top css properties are already updated to match the nodes positions.
    - _onBeforePlotNode(node)_ This method is triggered right before plotting a given node. The _node_ parameter is the <Graph.Node> to be plotted. 
This method is useful for changing a node style right before plotting it.
    - _onAfterPlotNode(node)_ This method is triggered right after plotting a given node. The _node_ parameter is the <Graph.Node> plotted.
    - _onBeforePlotLine(adj)_ This method is triggered right before plotting an edge. The _adj_ parameter is a <Graph.Adjacence> object. 
This method is useful for adding some styles to a particular edge before being plotted.
    - _onAfterPlotLine(adj)_ This method is triggered right after plotting an edge. The _adj_ parameter is the <Graph.Adjacence> plotted.

    Example:

    Here goes a complete example. In most cases you won't be forced to implement all properties and methods. In fact, 
    all configuration properties  have the default value assigned.

    I won't be instanciating a <Canvas> class here. If you want to know more about instanciating a <Canvas> class 
    please take a look at the <Canvas> class documentation.

    (start code js)
      var ht = new Hypertree(canvas, {
        
        Node: {
          overridable: false,
          type: 'circle',
          color: '#ccb',
          lineWidth: 1,
          height: 5,
          width: 5,
          dim: 7,
          transform: true
        },
        Edge: {
          overridable: false,
          type: 'hyperline',
          color: '#ccb',
          lineWidth: 1
        },
        duration: 1500,
        fps: 40,
        transition: Trans.Quart.easeInOut,
        clearCanvas: true,
        withLabels: true,
        
        onBeforeCompute: function(node) {
          //do something onBeforeCompute
        },
        onAfterCompute:  function () {
          //do something onAfterCompute
        },
        onCreateLabel:   function(domElement, node) {
          //do something onCreateLabel
        },
        onPlaceLabel:    function(domElement, node) {
          //do something onPlaceLabel
        },
        onBeforePlotNode:function(node) {
          //do something onBeforePlotNode
        },
        onAfterPlotNode: function(node) {
          //do something onAfterPlotNode
        },
        onBeforePlotLine:function(adj) {
          //do something onBeforePlotLine
        },
        onAfterPlotLine: function(adj) {
          //do something onAfterPlotLine
        }
      });
    (end code)

    Instance Properties:

    - _graph_ Access a <Graph> instance.
    - _op_ Access a <Hypertree.Op> instance.
    - _fx_ Access a <Hypertree.Plot> instance.
*/ 
 
this.Hypertree = new Class({ 
	 
	Implements: [Loader, AngularWidth], 
	 
	initialize: function(canvas, controller) { 
 
		var config = { 
                labelContainer: canvas.id + '-label', 
		         
                withLabels: true,
                
                Node: { 
                    overridable: false, 
                    type: 'circle', 
                    dim: 7, 
                    color: '#ccb', 
                    width: 5, 
                    height: 5,    
                    lineWidth: 1, 
                    transform: true 
                }, 
                 
                Edge: { 
                    overridable: false, 
                    type: 'hyperline', 
                    color: '#ccb', 
                    lineWidth: 1 
                }, 
                clearCanvas: true,
		        fps:40, 
		        duration: 1500, 
                transition: Trans.Quart.easeInOut 
		}; 
 
	    var innerController = { 
	        onBeforeCompute: $empty, 
	        onAfterCompute:  $empty, 
	        onCreateLabel:   $empty, 
	        onPlaceLabel:    $empty, 
	        onComplete:      $empty, 
	        onBeforePlotLine:$empty, 
	        onAfterPlotLine: $empty, 
	        onBeforePlotNode:$empty, 
	        onAfterPlotNode: $empty 
	    }; 
	     
	    this.controller = this.config = $merge(config, innerController, controller); 
        this.graphOptions = { 
            'complex': false, 
            'Node': { 
                'selected': false, 
                'exist': true, 
                'drawn': true 
            } 
        }; 
		this.graph = new Graph(this.graphOptions); 
		this.fx = new Hypertree.Plot(this); 
		this.op = new Hypertree.Op(this); 
	    this.json = null; 
	    this.canvas = canvas; 
 
	    this.root = null; 
	    this.busy = false; 
    }, 
 
    /* 
     Method: refresh 
     
     Computes nodes' positions and replots the tree.

     Parameters:

     reposition - _optional_ Set this to *true* to force repositioning.

     See also:

     <Hypertree.reposition>
      
    */ 
    refresh: function(reposition) { 
        if(reposition) { 
            this.reposition(); 
            Graph.Util.eachNode(this.graph, function(node) { 
                node.startPos.rho = node.pos.rho = node.endPos.rho;
                node.startPos.theta = node.pos.theta = node.endPos.theta; 
            }); 
        } else { 
            this.compute(); 
        } 
        this.plot(); 
    }, 
     
    /* 
     Method: reposition 
     
     Computes nodes' positions and restores the tree to its previous position.

     For calculating nodes' positions the root must be placed on its origin. This method does this 
       and then attemps to restore the hypertree to its previous position.
      
    */ 
    reposition: function() { 
        this.compute('endPos'); 
        var vector = this.graph.getNode(this.root).pos.getc().scale(-1); 
        Graph.Util.moebiusTransformation(this.graph, [vector], ['endPos'], 'endPos', "ignore"); 
        Graph.Util.eachNode(this.graph, function(node) { 
            if (node.ignore) {
                node.endPos.rho = node.pos.rho;
                node.endPos.theta = node.pos.theta;
            } 
        }); 
    }, 
 
    /* 
     Method: plot 
     
     Plots the Hypertree 

    */ 
    plot: function() { 
        this.fx.plot(); 
    }, 
     
    /* 
     Method: compute 
     
     Computes nodes' positions. 

     Parameters:

     property - _optional_ A <Graph.Node> position property to store the new positions. Possible values are 'pos', 'endPos' or 'startPos'.


    */ 
    compute: function(property) { 
        var prop = property || ['pos', 'startPos']; 
        var node = this.graph.getNode(this.root); 
        node._depth = 0; 
        Graph.Util.computeLevels(this.graph, this.root, 0, "ignore"); 
        this.computeAngularWidths(); 
        this.computePositions(prop); 
    }, 
     
    /* 
     computePositions 
     
     Performs the main algorithm for computing node positions.

     Parameters:

     property - A <Graph.Node> position property to store the new positions. Possible values are 'pos', 'endPos' or 'startPos'.

  */ 
    computePositions: function(property) { 
        var propArray = $splat(property); 
        var aGraph = this.graph, GUtil = Graph.Util; 
        var root = this.graph.getNode(this.root), that = this, config = this.config; 
        var size = this.canvas.getSize(); 
        var scale = Math.min(size.width, size.height)/ 2; 
 
 
        //Set default values for the root node 
        for(var i=0; i<propArray.length; i++)  
            root[propArray[i]] = $P(0, 0); 
        root.angleSpan = { 
            begin: 0, 
            end: 2 * Math.PI 
        }; 
		root._rel = 1; 
		 
        //Estimate better edge length. 
        var edgeLength = (function() { 
            var depth = 0; 
            GUtil.eachNode(aGraph, function(node) { 
                depth = (node._depth > depth)? node._depth : depth; 
				node._scale = scale; 
            }, "ignore"); 
            for(var i=0.51; i<=1; i+=.01) { 
                var valSeries = (function(a, n) { 
                    return (1 - Math.pow(a, n)) / (1 - a); 
                })(i, depth + 1); 
                if(valSeries >= 2) return i - .01; 
            } 
            return .5; 
        })(); 
         
        GUtil.eachBFS(this.graph, this.root, function (elem) { 
            var angleSpan = elem.angleSpan.end - elem.angleSpan.begin; 
            var angleInit = elem.angleSpan.begin; 
            var totalAngularWidths = (function (element){ 
                var total = 0; 
                GUtil.eachSubnode(element, function(sib) { 
                    total += sib._treeAngularWidth; 
                }, "ignore"); 
                return total; 
            })(elem); 
 
            for(var i=1, rho = 0, lenAcum = edgeLength, depth = elem._depth; i<=depth+1; i++) { 
                rho += lenAcum; 
                lenAcum *= edgeLength; 
            } 
             
            GUtil.eachSubnode(elem, function(child) { 
                if(!child._flag) { 
                    child._rel = child._treeAngularWidth / totalAngularWidths; 
                    var angleProportion = child._rel * angleSpan; 
                    var theta = angleInit + angleProportion / 2; 
 
                    for(var i=0; i<propArray.length; i++) 
                        child[propArray[i]] = $P(theta, rho); 
 
                    child.angleSpan = { 
                        begin: angleInit, 
                        end: angleInit + angleProportion 
                    }; 
                    angleInit += angleProportion; 
                } 
            }, "ignore"); 
 
        }, "ignore"); 
    }, 
     
    /* 
     Method: onClick 
     
     Performs all calculations and animations to center the node specified by _id_.

     Parameters:

     id - A <Graph.Node> id.
     opt - _optional_ An object containing some extra properties like

     - _hideLabels_ Hide labels when performing the animation. Default's *true*.

     Example:

     (start code js)
       ht.onClick('someid');
       //or also...
       ht.onClick('someid', {
        hideLabels: false
       });
      (end code)
      
    */ 
    onClick: function(id, opt) { 
        var pos = this.graph.getNode(id).pos.getc(true); 
        this.move(pos, opt); 
    }, 
     
    /* 
     Method: move 

     Translates the tree to the given position. 

     Parameters:

     pos - A <Complex> number determining the position to move the tree to.
     opt - _optional_ An object containing some extra properties defined in <Hypertree.onClick>


    */ 
    move: function(pos, opt) { 
        var versor = $C(pos.x, pos.y); 
        if(this.busy === false && versor.norm() < 1) { 
            var GUtil = Graph.Util;
            this.busy = true; 
            var root = GUtil.getClosestNodeToPos(this.graph, versor), that = this;
            GUtil.computeLevels(this.graph, root.id, 0);
            this.controller.onBeforeCompute(root); 
            if (versor.norm() < 1) { 
                opt = $merge({ onComplete: $empty }, opt || {}); 
                this.fx.animate($merge({ 
                    modes: ['moebius'], 
                    hideLabels: true 
                }, opt, { 
                    onComplete: function(){ 
                        that.busy = false; 
                        opt.onComplete(); 
                    } 
                }), versor); 
            } 
        } 
    }    
}); 
 
/* 
   Class: Hypertree.Op 
 
   Performs advanced operations on trees and graphs.

   Extends:

   All <Graph.Op> methods

   Access:

   This instance can be accessed with the _op_ parameter of the hypertree instance created.

   Example:

   (start code js)
    var ht = new Hypertree(canvas, config);
    ht.op.morph //or can also call any other <Graph.Op> method
   (end code)
    
*/ 
Hypertree.Op = new Class({ 
 
    Implements: Graph.Op, 
 
    initialize: function(viz) { 
        this.viz = viz; 
    } 
}); 
 
/* 
   Class: Hypertree.Plot 
 
   Performs plotting operations.

   Extends:

   All <Graph.Plot> methods

   Access:

   This instance can be accessed with the _fx_ parameter of the hypertree instance created.

   Example:

   (start code js)
    var ht = new Hypertree(canvas, config);
    ht.fx.placeLabel //or can also call any other <Hypertree.Plot> method
   (end code)

*/ 
Hypertree.Plot = new Class({ 
 
    Implements: Graph.Plot, 
	 
	initialize: function(viz) { 
        this.viz = viz; 
        this.config = viz.config; 
		this.node = this.config.Node; 
		this.edge = this.config.Edge; 
        this.animation = new Animation; 
        this.nodeTypes = new Hypertree.Plot.NodeTypes; 
        this.edgeTypes = new Hypertree.Plot.EdgeTypes; 
	}, 
     
    /* 
       Method: hyperline 
     
       Plots a hyperline between two nodes. A hyperline is an arc of a circle which is orthogonal to the main circle. 

       Parameters:

       adj - A <Graph.Adjacence> object.
       canvas - A <Canvas> instance.
    */ 
    hyperline: function(adj, canvas) { 
        var node = adj.nodeFrom, child = adj.nodeTo, data = adj.data; 
        var pos = node.pos.getc(), posChild = child.pos.getc(); 
        var centerOfCircle = this.computeArcThroughTwoPoints(pos, posChild); 
        var size = canvas.getSize(); 
        var scale = Math.min(size.width, size.height)/2; 
        if (centerOfCircle.a > 1000 || centerOfCircle.b > 1000 || centerOfCircle.ratio > 1000) { 
            canvas.path('stroke', function(ctx) { 
                ctx.moveTo(pos.x * scale, pos.y * scale); 
                ctx.lineTo(posChild.x * scale, posChild.y * scale); 
			}); 
		} else { 
	        var angleBegin = Math.atan2(posChild.y - centerOfCircle.y, posChild.x - centerOfCircle.x); 
	        var angleEnd   = Math.atan2(pos.y - centerOfCircle.y, pos.x - centerOfCircle.x); 
	        var sense      = this.sense(angleBegin, angleEnd); 
	        var context = canvas.getCtx(); 
	        canvas.path('stroke', function(ctx) { 
	            ctx.arc(centerOfCircle.x*scale, centerOfCircle.y*scale, centerOfCircle.ratio*scale, angleBegin, angleEnd, sense); 
	        }); 
		} 
    }, 
     
    /* 
       computeArcThroughTwoPoints 
     
       Calculates the arc parameters through two points.
       
       More information in <http://en.wikipedia.org/wiki/Poincar%C3%A9_disc_model#Analytic_geometry_constructions_in_the_hyperbolic_plane> 

       Parameters:

       p1 - A <Complex> instance.
       p2 - A <Complex> instance.

       Returns:

       An object containing some arc properties.
    */ 
    computeArcThroughTwoPoints: function(p1, p2) { 
        var aDen = (p1.x * p2.y - p1.y * p2.x), bDen = aDen; 
        var sq1 = p1.squaredNorm(), sq2 = p2.squaredNorm(); 
        //Fall back to a straight line 
        if (aDen == 0) return { x:0, y:0, ratio: 1001 }; 
 
        var a = (p1.y * sq2 - p2.y * sq1 + p1.y - p2.y) / aDen; 
        var b = (p2.x * sq1 - p1.x * sq2 + p2.x - p1.x) / bDen; 
        var x = -a / 2; 
        var y = -b / 2; 
        var squaredRatio = (a * a + b * b) / 4 -1; 
        //Fall back to a straight line         
        if(squaredRatio < 0) return { x:0, y:0, ratio: 1001 }; 
        var ratio = Math.sqrt(squaredRatio); 
        var out= { 
            x: x, 
            y: y, 
            ratio: ratio, 
            a: a, 
            b: b 
        }; 
 
        return out; 
  }, 
 
	/* 
	   sense 
	 
	   Sets angle direction to clockwise (true) or counterclockwise (false). 
	    
	   Parameters: 
	 
	      angleBegin - Starting angle for drawing the arc. 
	      angleEnd - The HyperLine will be drawn from angleBegin to angleEnd. 
	 
	   Returns: 
	 
	      A Boolean instance describing the sense for drawing the HyperLine. 
	*/ 
	sense: function(angleBegin, angleEnd) { 
	   return (angleBegin < angleEnd)? ((angleBegin + Math.PI > angleEnd)? false : true) :  
	       ((angleEnd + Math.PI > angleBegin)? true : false); 
	}, 
   

    /* 
      Method: placeLabel

      Overrides abstract method placeLabel in <Graph.Plot>.

      Parameters:

      tag - A DOM label element.
      node - A <Graph.Node>.
      controller - A configuration/controller object passed to the visualization.
     
     */
    placeLabel: function(tag, node, controller) { 
	    var pos = node.pos.getc(true), canvas = this.viz.canvas; 
	    var radius= canvas.getSize(); 
	    var scale = node._scale; 
	    var labelPos= { 
	        x: Math.round(pos.x * scale + radius.width/2), 
	        y: Math.round(pos.y * scale + radius.height/2) 
	    }; 
	    var style = tag.style; 
	    style.left = labelPos.x + 'px'; 
	    style.top  = labelPos.y + 'px'; 
	    style.display = ''; 
	    controller.onPlaceLabel(tag, node); 
	} 
}); 

/*
  Class: Hypertree.Plot.NodeTypes

  Here are implemented all kinds of node rendering functions. 
  Rendering functions implemented are 'none', 'circle', 'triangle', 'rectangle', 'star' and 'square'.

  You can add new Node types by implementing a new method in this class

  Example:

  (start code js)
    Hypertree.Plot.NodeTypes.implement({
      'newnodetypename': function(node, canvas) {
        //Render my node here.
      }
    });
  (end code)

*/
Hypertree.Plot.NodeTypes = new Class({ 
    'none': function() {}, 
     
    'circle': function(node, canvas) { 
        var nconfig = this.node, data = node.data; 
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim; 
		var p = node.pos.getc(), pos = p.scale(node._scale); 
		var prod = nconfig.transform?  nodeDim * (1 - p.squaredNorm()) : nodeDim; 
		if(prod >= nodeDim / 4) { 
	        canvas.path('fill', function(context) { 
	            context.arc(pos.x, pos.y, prod, 0, Math.PI * 2, true);           
	        }); 
		} 
    }, 
     
    'square': function(node, canvas) { 
        var nconfig = this.node, data = node.data; 
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim; 
        var p = node.pos.getc(), pos = p.scale(node._scale); 
        var prod = nconfig.transform?  nodeDim * (1 - p.squaredNorm()) : nodeDim; 
        var nodeDim2 = 2 * prod; 
        if (prod >= nodeDim / 4) { 
			canvas.getCtx().fillRect(pos.x - prod, pos.y - prod, nodeDim2, nodeDim2); 
		} 
    }, 
 
    'rectangle': function(node, canvas) { 
        var nconfig = this.node, data = node.data; 
        var width = nconfig.overridable && data && data.$width || nconfig.width; 
        var height = nconfig.overridable && data && data.$height || nconfig.height; 
        var p = node.pos.getc(), pos = p.scale(node._scale); 
		var prod = 1 - p.squaredNorm(); 
        width = nconfig.transform?  width * prod : width; 
		height = nconfig.transform?  height * prod : height; 
		if(prod >= 0.25) { 
            canvas.getCtx().fillRect(pos.x - width / 2, pos.y - height / 2, width, height);			 
		} 
 
    }, 
     
    'triangle': function(node, canvas) { 
        var nconfig = this.node, data = node.data; 
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim; 
        var p = node.pos.getc(), pos = p.scale(node._scale); 
        var prod = nconfig.transform?  nodeDim * (1 - p.squaredNorm()) : nodeDim; 
        if (prod >= nodeDim / 4) { 
			var c1x = pos.x,  
			c1y = pos.y - prod,  
			c2x = c1x - prod,  
			c2y = pos.y + prod,  
			c3x = c1x + prod,  
			c3y = c2y; 
			canvas.path('fill', function(ctx){ 
				ctx.moveTo(c1x, c1y); 
				ctx.lineTo(c2x, c2y); 
				ctx.lineTo(c3x, c3y); 
			}); 
		} 
    }, 
     
    'star': function(node, canvas) { 
        var nconfig = this.node, data = node.data; 
        var nodeDim = nconfig.overridable && data && data.$dim || nconfig.dim; 
        var p = node.pos.getc(), pos = p.scale(node._scale); 
        var prod = nconfig.transform?  nodeDim * (1 - p.squaredNorm()) : nodeDim; 
        if (prod >= nodeDim / 4) { 
			var ctx = canvas.getCtx(), pi5 = Math.PI / 5; 
			ctx.save(); 
			ctx.translate(pos.x, pos.y); 
			ctx.beginPath(); 
			ctx.moveTo(nodeDim, 0); 
			for (var i = 0; i < 9; i++) { 
				ctx.rotate(pi5); 
				if (i % 2 == 0) { 
					ctx.lineTo((prod / 0.525731) * 0.200811, 0); 
				} 
				else { 
					ctx.lineTo(prod, 0); 
				} 
			} 
			ctx.closePath(); 
			ctx.fill(); 
			ctx.restore(); 
		} 
    } 
}); 
 
 /*
  Class: Hypertree.Plot.EdgeTypes

  Here are implemented all kinds of edge rendering functions. 
  Rendering functions implemented are 'none', 'line' and 'hyperline'.

  You can add new Edge types by implementing a new method in this class

  Example:

  (start code js)
    Hypertree.Plot.EdgeTypes.implement({
      'newedgetypename': function(adj, canvas) {
        //Render my edge here.
      }
    });
  (end code)

*/
Hypertree.Plot.EdgeTypes = new Class({ 
    'none': function() {}, 
     
    'line': function(adj, canvas) { 
		var s = adj.nodeFrom._scale; 
        var pos = adj.nodeFrom.pos.getc(true); 
        var posChild = adj.nodeTo.pos.getc(true); 
        canvas.path('stroke', function(context) { 
            context.moveTo(pos.x * s, pos.y * s); 
            context.lineTo(posChild.x * s, posChild.y * s); 
        }); 
    }, 
 
    'hyperline': function(adj, canvas) { 
		this.hyperline(adj, canvas); 
	} 
}); 


/*
 * File: Treemap.js
 * 
 * Implements the <TM> class and other derived classes.
 *
 * Description:
 *
 * A Treemap is an information visualization technique, proven very useful when displaying large hierarchical structures on a constrained space. The idea behind a Treemap is to describe hierarchical relations as 'containment'. That means that if node B is child of node A, then B 'is contained' in A.
 *
 * Inspired by:
 *
 * Squarified Treemaps (Mark Bruls, Kees Huizing, and Jarke J. van Wijk) 
 *
 * <http://www.win.tue.nl/~vanwijk/stm.pdf>
 *
 * Tree visualization with tree-maps: 2-d space-filling approach (Ben Shneiderman)
 *
 * <http://hcil.cs.umd.edu/trs/91-03/91-03.html>
 *
 * Disclaimer:
 *
 * This visualization was built from scratch, taking only these papers as inspiration, and only shares some features with the Treemap papers mentioned above.
 *
 */

/*
   Object: TM

	Abstract Treemap object.

   Implemented By:
    
    <TM.Squarified>, <TM.Strip> and <TM.SliceAndDice>.

    Description:
    
    Implements layout and configuration options inherited by <TM.Squarified>, <TM.Strip> and <TM.SliceAndDice>.

    All Treemap constructors take the same configuration object as parameter.

    Two special _data_ keys are read from the JSON tree structure loaded by <Loader.loadJSON> to calculate 
    node's color and dimensions. These properties are $area (for nodes dimensions) and $color. Both of these properties are floats.

    This means that the tree structure defined in <Loader.loadJSON> should now look more like this

    (start code js)
        var json = {  
            "id": "aUniqueIdentifier",  
            "name": "usually a nodes name",  
            "data": {
                "$area": 33, //some float value
                "$color": 36, //-optional- some float value
                "some key": "some value",
                "some other key": "some other value"
             },  
            "children": [ 'other nodes or empty' ]  
        };  
    (end code)

    If you want to know more about JSON tree structures and the _data_ property please read <Loader.loadJSON>.

    Configuration:

    *General*

    - _rootId_ The id of the div container where the Treemap will be injected. Default's 'infovis'.
    - _orientation_ For <TM.Strip> and <TM.SliceAndDice> only. The layout algorithm orientation. Possible values are 'h' or 'v'.
    - _levelsToShow_ Max depth of the plotted tree. Useful when using the request method.
    - _addLeftClickHandler_ Add a left click event handler to zoom in the Treemap view when clicking a node. Default's *false*. 
    - _addRightClickHandler_ Add a right click event handler to zoom out the Treemap view. Default's *false*.
    - _selectPathOnHover_ If setted to *true* all nodes contained in the path between the hovered node and the root node will have an *in-path* CSS class. Default's *false*.

    *Nodes*
    
    There are two kinds of Treemap nodes.

    (see treemapnode.png)

    Inner nodes are nodes having children, like _Pearl Jam_.
    
    These nodes are represented by three div elements. A _content_ element, a _head_ element (where the title goes) and a _body_ element, where the children are laid out.
    
    (start code xml)
    <div class="content">
      <div class="head">Pearl Jam</div>
      <div class="body">...other nodes here...</div>
    </div>
    (end code)

      Leaves are optionally colored nodes laying at the "bottom" of the tree. For example, _Yield_, _Vs._ and _Riot Act_ are leaves.

    These nodes are represented by two div elements. A _content_ element and a wrapped _leaf_ element

    (start code xml)
    <div class="content">
      <div class="leaf">Yield</div>
    </div>
    (end code)

    There are some configuration properties regarding Treemap nodes

    - _titleHeight_ The height of the title (_head_) div container. Default's 13.
    - _offset_ The separation offset between the _content_ div element and its contained div(s). Default's 4.

    *Color*

    _Color_ is an object containing as properties

    - _allow_ If *true*, the algorithm will check for the JSON node data _$color_ property to add some color to the Treemap leaves. 
    This color is calculated by interpolating a node's $color value range with a real RGB color range. 
    By specifying min|maxValues for the $color property and min|maxColorValues for the RGB counterparts, the visualization is able to 
    interpolate color values and assign a proper color to the leaf node. Default's *false*.
    - _minValue_ The minimum value expected for the $color value property. Used for interpolating. Default's -100.
    - _maxValue_ The maximum value expected for the $color value property. Used for interpolating. Default's 100.
    - _minColorValue_ A three-element RGB array defining the color to be assigned to the _$color_ having _minValue_ as value. Default's [255, 0, 50].
    - _maxColorValue_ A three-element RGB array defining the color to be assigned to the _$color_ having _maxValue_ as value. Default's [0, 255, 50].

    *Tips*

    _Tips_ is an object containing as properties

    - _allow_ If *true*, a tooltip will be shown when a node is hovered. The tooltip is a div DOM element having "tip" as CSS class. Default's *false*. 
    - _offsetX_ An offset added to the current tooltip x-position (which is the same as the current mouse position). Default's 20.
    - _offsetY_ An offset added to the current tooltip y-position (which is the same as the current mouse position). Default's 20.
    - _onShow(tooltip, node, isLeaf, domElement)_ Implement this method to change the HTML content of the tooltip when hovering a node.
    
    Parameters:
      tooltip - The tooltip div element.
      node - The corresponding JSON tree node (See also <Loader.loadJSON>).
      isLeaf - Whether is a leaf or inner node.
      domElement - The current hovered DOM element.
    
    *Controller options*

    You can also implement controller functions inside the configuration object. These functions are
    
    - _onBeforeCompute(node)_ This method is called right before performing all computation and animations to the JIT visualization.
    - _onAfterCompute()_ This method is triggered right after all animations or computations for the JIT visualizations ended.
    - _onCreateElement(content, node, isLeaf, elem1, elem2)_ This method is called on each newly created node. 
    
    Parameters:
      content - The div wrapper element with _content_ className.
      node - The corresponding JSON tree node (See also <Loader.loadJSON>).
      isLeaf - Whether is a leaf or inner node. If the node's an inner tree node, elem1 and elem2 will become the _head_ and _body_ div elements respectively. 
      If the node's a _leaf_, then elem1 will become the div leaf element.
    
    - _onDestroyElement(content, node, isLeaf, elem1, elem2)_ This method is called before collecting each node. Takes the same parameters as onCreateElement.
    - _request(nodeId, level, onComplete)_ This method is used for buffering information into the visualization. When clicking on an empty node,
    the visualization will make a request for this node's subtrees, specifying a given level for this subtree (defined by _levelsToShow_). Once the request is completed, the _onComplete_ 
object should be called with the given result.

    See also <TM.Squarified>, <TM.SliceAndDice> and <TM.Strip>.


*/
this.TM = {

	layout: {
		orientation: "h",
		vertical: function() { 
			return this.orientation == "v"; 
		},
		horizontal: function() { 
			return this.orientation == "h"; 
		},
		change: function() { 
			this.orientation = this.vertical()? "h" : "v"; 
		}
	},
	
	innerController: {
			onBeforeCompute:  $empty,
			onAfterCompute:   $empty,
			onComplete:       $empty,
            onCreateElement:  $empty,
            onDestroyElement: $empty,
			request:          false
		},

		config: {
			orientation: "h",
			titleHeight: 13,
			rootId: 'infovis',
			offset:4,
			levelsToShow: 3,
            addLeftClickHandler: false,
            addRightClickHandler: false,
            selectPathOnHover: false,
            
			Color: {
				allow: false,
				minValue: -100,
				maxValue: 100,
				minColorValue: [255, 0, 50],
				maxColorValue: [0, 255, 50]
			},
            
            Tips: {
                allow: false,
                offsetX: 20,
                offsetY: 20,
                onShow: $empty
            }
		},
	

	initialize: function(controller) {
		this.tree = null;
		this.shownTree = null;
		this.controller = this.config = $merge(this.config, 
										this.innerController, 
										controller);
		this.rootId = this.config.rootId;
		this.layout.orientation = this.config.orientation;
        
        //add tooltip
        if(this.config.Tips.allow && document.body) {
            var tip = document.createElement('div');
            tip.id = '_tooltip';
            tip.className = 'tip';
            var style = tip.style;
            style.position = 'absolute';
            style.display = 'none';
            style.zIndex = 13000;
            document.body.appendChild(tip);
            this.tip = tip;
        }
        
        //purge
        var that = this;
        var fn = function() {
            that.empty();
            if(window.CollectGarbage) window.CollectGarbage();
            delete fn;
        };
        if(window.addEventListener) {
            window.addEventListener('unload', fn, false);
        } else {
            window.attachEvent('onunload', fn);
        }
	},

    /*
       Method: each
    
        Traverses head and leaf nodes applying a given function

      Parameters:
      
        f - A function that takes as parameters the same as the onCreateElement and onDestroyElement methods described in <TM>.
    */
    each: function(f) {
        (function rec(elem) {
          if(!elem) return;
          var ch = elem.childNodes, len = ch.length;
          if(len > 0) {
              f.apply(this, [elem, len === 1, ch[0], ch[1]]);
          }
          if (len > 1) {
            for(var chi = ch[1].childNodes, i=0; i<chi.length; i++) {
                rec(chi[i]);
            }
          }  
        })($get(this.rootId).firstChild);
    },

	/*
	   toStyle
	
		Transforms a JSON into a CSS style string.
	*/
	toStyle: function(obj) {
		var ans = "";
		for(var s in obj) ans += s + ":" + obj[s] + ";";
		return ans;
	},

	/*
	   leaf
	
		Returns a boolean value specifying if the node is a tree leaf or not.
	
	   Parameters:
	
	      tree - A tree node (which is also a JSON tree object of course). <http://blog.thejit.org>

	   Returns:
	
	   	  A boolean value specifying if the node is a tree leaf or not.
 
	*/
	leaf: function(tree) {
		return tree.children == 0;
	},

	/*
	   Method: createBox
	
		Constructs the proper DOM layout from a json node.
		
        If the node's an _inner node_, 
        this method calls <TM.contentBox>, <TM.bodyBox> and <TM.leafBox> 
        to create the following HTML structure
        
        (start code xml)
        <div class="content">
          <div class="head">[Node name]</div>
          <div class="body">[Node's children]</div>
        </div>
        (end code)

        If the node's a leaf node, it creates the following structure 
        by calling <TM.contentBox>, <TM.leafBox>

        (start code xml)
        <div class="content">
          <div class="leaf">[Node name]</div>
        </div>
        (end code)


	   Parameters:

	      json - A JSON subtree. See also <Loader.loadJSON>. 
		  coord - A coordinates object specifying width, height, left and top style properties.
          html - html to inject into the _body_ element if the node is an inner Tree node.

      Returns:

          The HTML structure described above.

      See also:

        <TM>, <TM.contentBox>, <TM.bodyBox>, <TM.headBox>, <TM.leafBox>.

	*/
	createBox: function(json, coord, html) {
		if(!this.leaf(json))
			var box = this.headBox(json, coord) + this.bodyBox(html, coord);
		 else 
			var box = this.leafBox(json, coord);
		return this.contentBox(json, coord, box);
	},
	
	/*
	   Method: plot
	
		Renders the Treemap.

      Parameters:

        json - A JSON tree structure preprocessed by some Treemap layout algorithm.

      Returns:

        The HTML to inject to the main visualization container.

      See also:

        <TM.createBox>.


	*/
	plot: function(json) {
		var coord = json.coord, html = "";
		
		if(this.leaf(json)) 
			return this.createBox(json, coord, null);
		
		for(var i=0, ch=json.children; i<ch.length; i++) 
			html+= this.plot(ch[i]);
		
		return this.createBox(json, coord, html);
	},


	/*
	   Method: headBox
	
		Creates the _head_ div dom element that usually contains the name of a parent JSON tree node.
	
	   Parameters:
	
	      json - A JSON subtree. See also <Loader.loadJSON>.
	      coord - width and height base coordinate object.

	   Returns:
	
	   	  A new _head_ div dom element that has _head_ as class name.

        See also:

          <TM.createBox>.
 
	*/
	headBox: function(json, coord) {
		var config = this.config, offst = config.offset;
		var c = {
			'height': config.titleHeight + "px",
			'width': (coord.width - offst) + "px",
			'left':  offst / 2 + "px"
		};
		return "<div class=\"head\" style=\"" + this.toStyle(c) + "\">"
				 + json.name + "</div>";
	},

	/*
	   Method: bodyBox
	
		Creates the _body_ div dom element that usually contains a subtree dom element layout.
	
	   Parameters:
	
	      html - html that should be contained in the body html.
	      coord - width and height base coordinate object.

	   Returns:
	
	   	  A new _body_ div dom element that has _body_ as class name.
 
        See also:

          <TM.createBox>.
 
	*/
	bodyBox: function(html, coord) {
		var config = this.config,
		th = config.titleHeight,
		offst = config.offset;
		var c = {
			'width': (coord.width - offst) + "px",
			'height':(coord.height - offst - th) + "px",
			'top':   (th + offst / 2) +  "px",
			'left':  (offst / 2) + "px"
		};
		return "<div class=\"body\" style=\""
		  + this.toStyle(c) +"\">" + html + "</div>";
	},



	/*
	   Method: contentBox
	
		Creates the _content_ div dom element that usually contains a _leaf_ div dom element or _head_ and _body_ div dom elements.
	
	   Parameters:
	
	      json - A JSON node. See also <Loader.loadJSON>. 
	      coord - An object containing width, height, left and top coordinates.
	      html - input html wrapped by this tag.
	      
	   Returns:
	
	   	  A new _content_ div dom element that has _content_ as class name.

       See also:

          <TM.createBox>.
 
	*/
	contentBox: function(json, coord, html) {
		var c = {};
		for(var i in coord) c[i] = coord[i] + "px";
		return "<div class=\"content\" style=\"" + this.toStyle(c) 
		   + "\" id=\"" + json.id + "\">" + html + "</div>";
	},


	/*
	   Method: leafBox
	
		Creates the _leaf_ div dom element that usually contains nothing else.
	
	   Parameters:
	
	      json - A JSON subtree. See also <Loader.loadJSON>. 
	      coord - base with and height coordinate object.
	      
	   Returns:
	
	   	  A new _leaf_ div dom element having _leaf_ as class name.
 
       See also:

          <TM.createBox>.
 

	*/
	leafBox: function(json, coord) {
		var config = this.config;
		var backgroundColor = config.Color.allow && this.setColor(json), 
		offst = config.offset,
		width = coord.width - offst,
		height = coord.height - offst;
		var c = {
			'top':   (offst / 2)  + "px",
			'height':height + "px",
			'width': width + "px",
			'left': (offst / 2) + "px"
		};
		if(backgroundColor) c['background-color'] = backgroundColor;
		return "<div class=\"leaf\" style=\"" + this.toStyle(c) + "\">" 
				+ json.name + "</div>";
	},


	/*
	   Method: setColor
	
	      Calculates an hexa color string based on the _$color_ data node property.	
	
          This method is called by <TM.leafBox> to assign an hexadecimal color to each leaf node.
          
          This color is calculated by making a linear interpolation between _$color_ max and min values and 
          RGB max and min values so that

          > hex = (maxColorValue - minColorValue) / (maxValue - minValue) * (x - minValue) + minColorValue

          where _x_ range is [minValue, maxValue] and 

          - _minValue_
          - _maxValue_
          - _minColorValue_
          - _maxColorValue_

        are defined in the <TM> configuration object.

        This method is called by <TM.leafBox> iif _Color.allow_ is setted to _true_.

        Sometimes linear interpolation for coloring is just not enough. In that case you can re-implement this 
        method so that it fits your coloring needs.

        Some people might find useful to implement their own coloring interpolation method and to assign the resulting hex string 
        to the _$color_ property. In that case we could re-implement the <TM.setColor> method like this

        (start code js)
          //TM.Strip, TM.SliceAndDice also work
          TM.Squarified.implement({
            'setColor': function(json) {
              return json.data.$color;
            }
          });
        (end code)

      So that it returns the previously assigned hex string.

	   Parameters:
	
	      json - A JSON tree node.

	   Returns:
	
	   	  A String that represents a color in hex value.
 
	*/
	setColor: function(json) {
		var c = this.config.Color,
		maxcv = c.maxColorValue,
		mincv = c.minColorValue,
		maxv = c.maxValue,
		minv = c.minValue,
		diff = maxv - minv,
		x = (json.data.$color - 0);
		//linear interpolation		
		var comp = function(i, x) { 
			return Math.round((((maxcv[i] - mincv[i]) / diff) * (x - minv) + mincv[i])); 
		};
		
		return $rgbToHex([ comp(0, x), comp(1, x), comp(2, x) ]);
	},

	/*
	   Method: enter
	
		Sets the _elem_ parameter as root and performs the layout.
	
	   Parameters:
	
	      elem - A JSON Tree node. See also <Loader.loadJSON>. 
	*/
	enter: function(elem) {
		this.view(elem.parentNode.id);
	},
	
    /*
       Method: onLeftClick
    
        Sets the _elem_ parameter as root and performs the layout. 
        This method is called when _addLeftClickHandler_ is *true* and a 
        node is left-clicked. You can override this method to add some custom behavior 
        when the node is left clicked though.
        
        An Example for overriding this method could be
        (start code js)
        //TM.Strip or TM.SliceAndDice also work
        TM.Squarified.implement({
            'onLeftClick': function(elem) {
                //some custom code...
            }
        });
        (end code)
        
    
       Parameters:
    
          elem - A JSON Tree node. See also <Loader.loadJSON>.
          
       See also:
       
          <TM.enter>
    */
    onLeftClick: function(elem) {
        this.enter(elem);
    },

	/*
	   Method: out
	
		Sets the _parent_ node of the currently shown subtree as root and performs the layout.
	
	*/
	out: function() {
		var parent = TreeUtil.getParent(this.tree, this.shownTree.id);
		if(parent) {
			if(this.controller.request)
				TreeUtil.prune(parent, this.config.levelsToShow);
			this.view(parent.id);
		}
	},
	
    /*
       Method: onRightClick
    
        Sets the _parent_ node of the currently shown subtree as root and performs the layout. 
        This method is called when _addRightClickHandler_ is *true* and a 
        node is right-clicked. You can override this method to add some custom behavior 
        when the node is right-clicked though.

        An Example for overriding this method could be
        (start code js)
        //TM.Strip or TM.SliceAndDice also work
        TM.Squarified.implement({
            'onRightClick': function() {
                //some custom code...
            }
        });
        (end code)

       See also:
       
          <TM.out>

    */
    onRightClick: function() {
        this.out();
    },

	/*
	   Method: view
	
		Sets the root of the treemap to the specified node id and performs the layout.
	
	   Parameters:
	
		  id - A node identifier
	*/
	view: function(id) {
		var config = this.config, that = this;
		var post = {
			onComplete: function() {
				that.loadTree(id);
				$get(config.rootId).focus();
			}
		};

		if (this.controller.request) {
			var TUtil = TreeUtil;
			TUtil.loadSubtrees(TUtil.getSubtree(this.tree, id),
							 $merge(this.controller, post));
		} else {
			post.onComplete();
		}
	},
	
	/*
	   Method: resetPath
	
       Sets an 'in-path' className for _leaf_ and _head_ elements which belong to the path between the given tree node 
       and the visualization's root node.
	
	   Parameters:
	
	      tree - A JSON  tree node. See also <Loader.loadJSON>.
	*/
	resetPath: function(tree) {
		var root = this.rootId, previous = this.resetPath.previous;
        this.resetPath.previous = tree || false;
        function getParent(c) { 
            var p = c.parentNode;
            return p && (p.id != root) && p;
         };
         function toggleInPath(elem, remove) {
            if(elem) {
                var container = $get(elem.id);
                if(container) {
                    var parent = getParent(container);
                    while(parent) {
                        var elem = parent.childNodes[0]
                        if($hasClass(elem, 'in-path')) {
                            if(remove == undefined || !!remove) $removeClass(elem, 'in-path');
                        } else {
                            if(!remove) $addClass(elem, 'in-path');
                        }
                        parent = getParent(parent);
                    }
                }
            }
         };
         toggleInPath(previous, true);
         toggleInPath(tree, false);                
	},

    
    /*
       Method: initializeElements
    
       Traverses the DOM tree applying the onCreateElement method.

       The onCreateElement controller method should attach events and add some behavior to the DOM element
       node created. *By default, the Treemap wont add any event to its elements.*
    */
    initializeElements: function() {
      var cont = this.controller, that = this;
      var ff = $lambda(false), tipsAllow = cont.Tips.allow;
      this.each(function(content, isLeaf, elem1, elem2) {
          var tree = TreeUtil.getSubtree(that.tree, content.id);
          cont.onCreateElement(content, tree, isLeaf, elem1, elem2);

          //eliminate context menu when right clicking
          if(cont.addRightClickHandler) elem1.oncontextmenu = ff;

          //add click handlers
          if(cont.addLeftClickHandler || cont.addRightClickHandler) {
            $addEvent(elem1, 'mouseup', function(e) {
                var rightClick = (e.which == 3 || e.button == 2);
                if (rightClick) {
                    if(cont.addRightClickHandler) that.onRightClick();
                }                     
                else {
                    if(cont.addLeftClickHandler) that.onLeftClick(elem1);
                } 
                    
                //prevent default 
                if (e.preventDefault) 
                    e.preventDefault();
                else 
                    e.returnValue = false;
            });
          }
          
          //add path selection on hovering nodes
          if(cont.selectPathOnHover || tipsAllow) {
            $addEvent(elem1, 'mouseover', function(e){
                if(cont.selectPathOnHover) {
                    if (isLeaf) {
                        $addClass(elem1, 'over-leaf');
                    }
                    else {
                        $addClass(elem1, 'over-head');
                        $addClass(content, 'over-content');
                    }
                    if (content.id) 
                        that.resetPath(tree);
                }
                if(tipsAllow)
                    cont.Tips.onShow(that.tip, tree, isLeaf, elem1);
            });
            
            $addEvent(elem1, 'mouseout', function(e){
                if(cont.selectPathOnHover) {
                    if (isLeaf) {
                        $removeClass(elem1, 'over-leaf');
                    }
                    else {
                        $removeClass(elem1, 'over-head');
                        $removeClass(content, 'over-content');
                    }
                    that.resetPath();
                }
                if(tipsAllow)
                    that.tip.style.display = 'none';
            });

            if(tipsAllow) {
                //Add mousemove event handler
                $addEvent(elem1, 'mousemove', function(e, win){
                    var tip = that.tip;
                    //get mouse position
                    win = win  || window;
                    e = e || win.event;
                    var doc = win.document;
                    doc = doc.html || doc.body;
                    var page = {
                        x: e.pageX || e.clientX + doc.scrollLeft,
                        y: e.pageY || e.clientY + doc.scrollTop
                    };
                    tip.style.display = '';
                    //get window dimensions
                    var win = {
                        'height': document.body.clientHeight,
                        'width': document.body.clientWidth
                    };
                    //get tooltip dimensions
                    var obj = {
                      'width': tip.offsetWidth,
                      'height': tip.offsetHeight  
                    };
                    //set tooltip position
                    var style = tip.style, x = cont.Tips.offsetX, y = cont.Tips.offsetY;
                    style.top = ((page.y + y + obj.height > win.height)?  
                        (page.y - obj.height - y) : page.y + y) + 'px';
                    style.left = ((page.x + obj.width + x > win.width)? 
                        (page.x - obj.width - x) : page.x + x) + 'px';
                });
            }
          }
      });
    },

    /*
       Method: destroyElements
    
       Traverses the tree applying the onDestroyElement method.

       The onDestroyElement controller method should detach events and garbage collect the element.
       *By default, the Treemap adds some garbage collect facilities for IE.*
    */
    destroyElements: function() {
      if(this.controller.onDestroyElement != $empty) {
          var cont = this.controller, that = this;
          this.each(function(content, isLeaf, elem1, elem2) {
              cont.onDestroyElement(content, TreeUtil.getSubtree(that.tree, content.id), isLeaf, elem1, elem2);
          });
      }  
    },
    
    /*
       Method: empty
    
        Empties the Treemap container (trying also to garbage collect things).
    */
    empty: function() {
        this.destroyElements();
        $clean($get(this.rootId));
    },

	/*
	   Method: loadTree
	
		Loads the subtree specified by _id_ and plots it on the layout container.
	
	   Parameters:
	
	      id - A subtree id.
	*/
	loadTree: function(id) {
		this.empty();
		this.loadJSON(TreeUtil.getSubtree(this.tree, id));
	}
	
};

/*
   Class: TM.SliceAndDice

	A JavaScript implementation of the Slice and Dice Treemap algorithm.

	The <TM.SliceAndDice> constructor takes an _optional_ configuration object described in <TM>.

    This visualization (as all other Treemap visualizations) is fed with JSON Tree structures.

    The _$area_ node data key is required for calculating rectangles dimensions.

    The _$color_ node data key is required if _Color_ _allow_ is *true* and is used for calculating 
    leaves colors.

    Extends:
    <TM>

    Parameters:

    config - Configuration defined in <TM>.

    Example:


	Here's a way of instanciating the <TM.SliceAndDice> will all its _optional_ configuration features
	
	(start code js)

	var tm = new TM.SliceAndDice({
  		orientation: "h",
		titleHeight: 13,
		rootId: 'infovis',
		offset:4,
		levelsToShow: 3,
        addLeftClickHandler: false,
        addRightClickHandler: false,
        selectPathOnHover: false,
            
		Color: {
			allow: false,
			minValue: -100,
			maxValue: 100,
			minColorValue: [255, 0, 50],
			maxColorValue: [0, 255, 50]
          },
          
          Tips: {
            allow: false,
            offsetX; 20,
            offsetY: 20,
            onShow: function(tooltip, node, isLeaf, domElement) {}
          },
            
          onBeforeCompute:  function(node) {
            //Some stuff on before compute...
          },
          onAfterCompute:   function() {
            //Some stuff on after compute...
          },
          onCreateElement:  function(content, node, isLeaf, head, body) {
            //Some stuff onCreateElement
          },
          onDestroyElement: function(content, node, isLeaf, head, body) {
            //Some stuff onDestroyElement
          },
    	  request:          false
    });
	tm.loadJSON(json);

	(end code)

*/
TM.SliceAndDice = new Class({
	Implements: TM,
	/*
	   Method: loadJSON
	
		Loads the specified JSON tree and lays it on the main container.
	
	   Parameters:
	
	      json - A JSON Tree. See also <Loader.loadJSON>. 
	*/
	loadJSON: function (json) {
		this.controller.onBeforeCompute(json);
		var container = $get(this.rootId),
		config = this.config,
		width = container.offsetWidth,
		height = container.offsetHeight;
		
		var p = {
			'coord': {
				'top': 0,
				'left': 0,
				'width':  width,
				'height': height + config.titleHeight + config.offset
			}
		};
		
		if(this.tree == null) this.tree = json;
		this.shownTree = json;
		this.compute(p, json, this.layout.orientation);
		container.innerHTML = this.plot(json);
        this.initializeElements();
		this.controller.onAfterCompute(json);
	},
	
	/*
	   Method: compute
	
		Called by loadJSON to calculate recursively all node positions and lay out the tree.
	
	   Parameters:

	      par - The parent node of the json subtree.	
	      json - A JSON subtree. See also <Loader.loadJSON>.
	      orientation - The current orientation. This value is switched recursively.
	*/
	compute: function(par, json, orientation) {
		var config = this.config, 
		coord = par.coord,
		offst = config.offset,
		width  = coord.width - offst,
		height = coord.height - offst - config.titleHeight,
		pdata = par.data,
		fact = (pdata && ("$area" in pdata))? json.data.$area / pdata.$area : 1;

		var horizontal = (orientation == "h");
		if(horizontal) {
			orientation = 'v';		
			var size = Math.round(width * fact),
			otherSize = height,
			dim = 'height',
			pos = 'top',
			pos2 = 'left';
		} else {
			orientation = 'h';		
			var otherSize = Math.round(height * fact),
			size = width,
			dim = 'width',
			pos = 'left',
			pos2 = 'top';
		}
		json.coord = {
			'width':size,
			'height':otherSize,
			'top':0,
			'left':0
		};
		var offsetSize = 0, tm = this;
		$each(json.children, function(elem){
			tm.compute(json, elem, orientation);
			elem.coord[pos] = offsetSize;
			elem.coord[pos2] = 0;
			offsetSize += Math.floor(elem.coord[dim]);
		});
	}
});


/*
   Class: TM.Area

	Abstract Treemap class containing methods that are common to
	 aspect ratio related algorithms such as <TM.Squarified> and <TM.Strip>.

    Implemented by:

    <TM.Squarified>, <TM.Strip>
*/
TM.Area = new Class({

	/*
	   Method: loadJSON
	
		Loads the specified JSON tree and lays it on the main container.
	
	   Parameters:
	
	      json - A JSON tree. See also <Loader.loadJSON>.
	*/
	loadJSON: function (json) {
		this.controller.onBeforeCompute(json);
		var container = $get(this.rootId),
		width = container.offsetWidth,
		height = container.offsetHeight,
		offst = this.config.offset,
		offwdth = width - offst,
		offhght = height - offst - this.config.titleHeight;

		json.coord =  {
			'height': height,
			'width': width,
			'top': 0,
			'left': 0
		};
		var coord = $merge(json.coord, {
			'width': offwdth,
			'height': offhght
		});

		this.compute(json, coord);
		container.innerHTML = this.plot(json);
		if(this.tree == null) this.tree = json;
		this.shownTree = json;
		this.initializeElements();
		this.controller.onAfterCompute(json);
	},
	
	/*
	   Method: computeDim
	
		Computes dimensions and positions of a group of nodes
		according to a custom layout row condition. 
	
	   Parameters:

	      tail - An array of nodes.	
          initElem - An array of nodes (containing the initial node to be laid).
	      w - A fixed dimension where nodes will be layed out.
		  coord - A coordinates object specifying width, height, left and top style properties.
		  comp - A custom comparison function
	*/
	computeDim: function(tail, initElem, w, coord, comp) {
		if(tail.length + initElem.length == 1) {
			var l = (tail.length == 1)? tail : initElem;
			this.layoutLast(l, w, coord);
			return;
		}
		if(tail.length >= 2 && initElem.length == 0) {
			initElem = [tail[0]];
			tail = tail.slice(1);
		}
		if(tail.length == 0) {
			if(initElem.length > 0) this.layoutRow(initElem, w, coord);
			return;
		}
		var c = tail[0];
		if(comp(initElem, w) >= comp([c].concat(initElem), w)) {
			this.computeDim(tail.slice(1), initElem.concat([c]), w, coord, comp);
		} else {
			var newCoords = this.layoutRow(initElem, w, coord);
			this.computeDim(tail, [], newCoords.dim, newCoords, comp);
		}
	},

	
	/*
	   Method: worstAspectRatio
	
		Calculates the worst aspect ratio of a group of rectangles. 
        
        See also:
        
        <http://en.wikipedia.org/wiki/Aspect_ratio>
		
	   Parameters:

		  ch - An array of nodes.	
	      w - The fixed dimension where rectangles are being laid out.

	   Returns:
	
	   	  The worst aspect ratio.
 

	*/
	worstAspectRatio: function(ch, w) {
		if(!ch || ch.length == 0) return Number.MAX_VALUE;
		var areaSum = 0, maxArea = 0, minArea = Number.MAX_VALUE;
		for(var i=0; i<ch.length; i++) {
			var area = ch[i]._area;
			areaSum += area; 
			minArea = (minArea < area)? minArea : area;
			maxArea = (maxArea > area)? maxArea : area; 
		}
		var sqw = w * w, sqAreaSum = areaSum * areaSum;
		return Math.max(sqw * maxArea / sqAreaSum,
						sqAreaSum / (sqw * minArea));
	},
	
	/*
	   Method: avgAspectRatio
	
		Calculates the average aspect ratio of a group of rectangles. 
        
        See also:
        
        <http://en.wikipedia.org/wiki/Aspect_ratio>
		
	   Parameters:

		  ch - An array of nodes.	
	      w - The fixed dimension where rectangles are being laid out.

	   Returns:
	
	   	  The average aspect ratio.
 

	*/
	avgAspectRatio: function(ch, w) {
		if(!ch || ch.length == 0) return Number.MAX_VALUE;
		var arSum = 0;
		for(var i=0; i<ch.length; i++) {
			var area = ch[i]._area;
			var h = area / w;
			arSum += (w > h)? w / h : h / w;
		}
		return arSum / ch.length;
	},

	/*
	   layoutLast
	
		Performs the layout of the last computed sibling.
	
	   Parameters:

	      ch - An array of nodes.	
	      w - A fixed dimension where nodes will be layed out.
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	layoutLast: function(ch, w, coord) {
		ch[0].coord = coord;
	}
	
});




/*
   Class: TM.Squarified

	A JavaScript implementation of the Squarified Treemap algorithm.

	The <TM.Squarified> constructor takes an _optional_ configuration object described in <TM>.

    This visualization (as all other Treemap visualizations) is fed with JSON Tree structures.

    The _$area_ node data key is required for calculating rectangles dimensions.

    The _$color_ node data key is required if _Color_ _allow_ is *true* and is used for calculating 
    leaves colors.

    Extends:
    <TM> and <TM.Area>

    Parameters:

    config - Configuration defined in <TM>.

    Example:


	Here's a way of instanciating the <TM.Squarified> will all its _optional_ configuration features
	
	(start code js)

	var tm = new TM.Squarified({
		titleHeight: 13,
		rootId: 'infovis',
		offset:4,
		levelsToShow: 3,
        addLeftClickHandler: false,
        addRightClickHandler: false,
        selectPathOnHover: false,
            
		Color: {
			allow: false,
			minValue: -100,
			maxValue: 100,
			minColorValue: [255, 0, 50],
			maxColorValue: [0, 255, 50]
          },
          
          Tips: {
            allow: false,
            offsetX: 20,
            offsetY: 20,
            onShow: function(tooltip, node, isLeaf, domElement) {}
          },
  
          onBeforeCompute:  function(node) {
            //Some stuff on before compute...
          },
          onAfterCompute:   function() {
            //Some stuff on after compute...
          },
          onCreateElement:  function(content, node, isLeaf, head, body) {
            //Some stuff onCreateElement
          },
          onDestroyElement: function(content, node, isLeaf, head, body) {
            //Some stuff onDestroyElement
          },
    	  request:          false
    });
	tm.loadJSON(json);

	(end code)

*/
	
TM.Squarified = new Class({
	Implements: [TM, TM.Area],

	/*
	   Method: compute
	
		Called by loadJSON to calculate recursively all node positions and lay out the tree.
	
	   Parameters:

	      json - A JSON tree. See also <Loader.loadJSON>.
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	compute: function(json, coord) {
		if (!(coord.width >= coord.height && this.layout.horizontal())) 
			this.layout.change();
		var ch = json.children, config = this.config;
		if(ch.length > 0) {
			this.processChildrenLayout(json, ch, coord);
			for(var i=0; i<ch.length; i++) {
				var chcoord = ch[i].coord,
				offst = config.offset,
				height = chcoord.height - (config.titleHeight + offst),
				width = chcoord.width - offst;
				var coord = {
					'width':width,
					'height':height,
					'top':0,
					'left':0
				};
				this.compute(ch[i], coord);
			}
		}
	},

	/*
	   Method: processChildrenLayout
	
		Computes children real areas and other useful parameters for performing the Squarified algorithm.
	
	   Parameters:

	      par - The parent node of the json subtree.	
	      ch - An Array of nodes
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	processChildrenLayout: function(par, ch, coord) {
		//compute children real areas
		var parentArea = coord.width * coord.height;
		for(var totalChArea=0, chArea = [], i=0; i < ch.length; i++) {
            chArea[i] = parseFloat(ch[i].data.$area);
            totalChArea += chArea[i];
        }
        for(var i=0; i<chArea.length; i++) {
			ch[i]._area = parentArea * chArea[i] / totalChArea;
		}
		var minimumSideValue = (this.layout.horizontal())? coord.height : coord.width;
		ch.sort(function(a, b) { return (a._area <= b._area) - (a._area >= b._area); });
		var initElem = [ch[0]];
		var tail = ch.slice(1);
		this.squarify(tail, initElem, minimumSideValue, coord);
	},

	/*
	   Method: squarify
	
		Performs an heuristic method to calculate div elements sizes in order to have a good aspect ratio.
	
	   Parameters:

	      tail - An array of nodes.	
	      initElem - An array of nodes, containing the initial node to be laid out.
	      w - A fixed dimension where nodes will be laid out.
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	squarify: function(tail, initElem, w, coord) {
		this.computeDim(tail, initElem, w, coord, this.worstAspectRatio);
	},
	
	/*
	   Method: layoutRow
	
		Performs the layout of an array of nodes.
	
	   Parameters:

	      ch - An array of nodes.	
	      w - A fixed dimension where nodes will be laid out.
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	layoutRow: function(ch, w, coord) {
		if(this.layout.horizontal()) {
			return this.layoutV(ch, w, coord);
		} else {
			return this.layoutH(ch, w, coord);
		}
	},
	
	layoutV: function(ch, w, coord) {
		var totalArea = 0; 
		$each(ch, function(elem) { totalArea += elem._area; });
		var width = totalArea / w, top =  0; 
		for(var i=0; i<ch.length; i++) {
			var h = ch[i]._area / width;
			ch[i].coord = {
				'height': h,
				'width': width,
				'top': coord.top + (w - h - top),
				'left': coord.left
			};
			top += h;
		}
		var ans = {
			'height': coord.height,
			'width': coord.width - width,
			'top': coord.top,
			'left': coord.left + width
		};
		//take minimum side value.
		ans.dim = Math.min(ans.width, ans.height);
		if(ans.dim != ans.height) this.layout.change();
		return ans;
	},
	
	layoutH: function(ch, w, coord) {
		var totalArea = 0; 
		$each(ch, function(elem) { totalArea += elem._area; });
		var height = totalArea / w,
		top = coord.height - height, 
		left = 0;
		
		for(var i=0; i<ch.length; i++) {
			ch[i].coord = {
				'height': height,
				'width': ch[i]._area / height,
				'top': top,
				'left': coord.left + left
			};
			left += ch[i].coord.width;
		}
		var ans = {
			'height': coord.height - height,
			'width': coord.width,
			'top': coord.top,
			'left': coord.left
		};
		ans.dim = Math.min(ans.width, ans.height);
		if(ans.dim != ans.width) this.layout.change();
		return ans;
	}
});


/*
   Class: TM.Strip

	A JavaScript implementation of the Strip Treemap algorithm.

	The <TM.Strip> constructor takes an _optional_ configuration object described in <TM>.

    This visualization (as all other Treemap visualizations) is fed with JSON Tree structures.

    The _$area_ node data key is required for calculating rectangles dimensions.

    The _$color_ node data key is required if _Color_ _allow_ is *true* and is used for calculating 
    leaves colors.

    Extends:
    <TM> and <TM.Area>

    Parameters:
    
    config - Configuration defined in <TM>.

    Example:


	Here's a way of instanciating the <TM.Strip> will all its _optional_ configuration features
	
	(start code js)

	var tm = new TM.Strip({
		titleHeight: 13,
  		orientation: "h",
		rootId: 'infovis',
		offset:4,
		levelsToShow: 3,
        addLeftClickHandler: false,
        addRightClickHandler: false,
        selectPathOnHover: false,
            
		Color: {
			allow: false,
			minValue: -100,
			maxValue: 100,
			minColorValue: [255, 0, 50],
			maxColorValue: [0, 255, 50]
          },
          
          Tips: {
            allow: false,
            offsetX: 20,
            offsetY: 20,
            onShow: function(tooltip, node, isLeaf, domElement) {}
          },
  
          onBeforeCompute:  function(node) {
            //Some stuff on before compute...
          },
          onAfterCompute:   function() {
            //Some stuff on after compute...
          },
          onCreateElement:  function(content, node, isLeaf, head, body) {
            //Some stuff onCreateElement
          },
          onDestroyElement: function(content, node, isLeaf, head, body) {
            //Some stuff onDestroyElement
          },
    	  request:          false
    });
	tm.loadJSON(json);

	(end code)

*/
	
TM.Strip = new Class({
	Implements: [ TM, TM.Area ],

	/*
	   Method: compute
	
		Called by loadJSON to calculate recursively all node positions and lay out the tree.
	
	   Parameters:

	      json - A JSON subtree. See also <Loader.loadJSON>. 
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	compute: function(json, coord) {
		var ch = json.children, config = this.config;
		if(ch.length > 0) {
			this.processChildrenLayout(json, ch, coord);
			for(var i=0; i<ch.length; i++) {
				var chcoord = ch[i].coord,
				offst = config.offset,
				height = chcoord.height - (config.titleHeight + offst),
				width = chcoord.width - offst;
				var coord = {
					'width':width,
					'height':height,
					'top':0,
					'left':0
				};
				this.compute(ch[i], coord);
			}
		}
	},

	/*
	   Method: processChildrenLayout
	
		Computes children real areas and other useful parameters for performing the Strip algorithm.
	
	   Parameters:

	      par - The parent node of the json subtree.	
	      ch - An Array of nodes
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	processChildrenLayout: function(par, ch, coord) {
		//compute children real areas
		var area = coord.width * coord.height;
		var dataValue = parseFloat(par.data.$area);
		$each(ch, function(elem) {
			elem._area = area * parseFloat(elem.data.$area) / dataValue;
		});
		var side = (this.layout.horizontal())? coord.width : coord.height;
		var initElem = [ch[0]];
		var tail = ch.slice(1);
		this.stripify(tail, initElem, side, coord);
	},

	/*
	   Method: stripify
	
		Performs an heuristic method to calculate div elements sizes in order to have 
		a good compromise between aspect ratio and order.
	
	   Parameters:

	      tail - An array of nodes.	
	      initElem - An array of nodes.
	      w - A fixed dimension where nodes will be layed out.
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	stripify: function(tail, initElem, w, coord) {
		this.computeDim(tail, initElem, w, coord, this.avgAspectRatio);
	},
	
	/*
	   Method: layoutRow
	
		Performs the layout of an array of nodes.
	
	   Parameters:

	      ch - An array of nodes.	
	      w - A fixed dimension where nodes will be laid out.
		  coord - A coordinates object specifying width, height, left and top style properties.
	*/
	layoutRow: function(ch, w, coord) {
		if(this.layout.horizontal()) {
			return this.layoutH(ch, w, coord);
		} else {
			return this.layoutV(ch, w, coord);
		}
	},
	
	layoutV: function(ch, w, coord) {
		var totalArea = 0; 
		$each(ch, function(elem) { totalArea += elem._area; });
		var width = (totalArea / w), top =  0; 
		for(var i=0; i<ch.length; i++) {
			var h = (ch[i]._area / width);
			ch[i].coord = {
				'height': h,
				'width': width,
				'top': coord.top + (w - h - top),
				'left': coord.left
			};
			top += h;
		}

		var ans = {
			'height': coord.height,
			'width': coord.width - width,
			'top': coord.top,
			'left': coord.left + width,
			'dim': w
		};
		return ans;
	},
	
	layoutH: function(ch, w, coord) {
		var totalArea = 0; 
		$each(ch, function(elem) { totalArea += elem._area; });
		var height = totalArea / w,
		top = coord.height - height, 
		left = 0;
		
		for(var i=0; i<ch.length; i++) {
			ch[i].coord = {
				'height': height,
				'width': ch[i]._area / height,
				'top': top,
				'left': coord.left + left
			};
			left += ch[i].coord.width;
		}
		var ans = {
			'height': coord.height - height,
			'width': coord.width,
			'top': coord.top,
			'left': coord.left,
			'dim': w
		};
		return ans;
	}
});





 })();