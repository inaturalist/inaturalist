# angular-fontawesome [![Build Status](https://travis-ci.org/picardy/angular-fontawesome.svg?branch=master)](https://travis-ci.org/picardy/angular-fontawesome)

[![Join the chat at https://gitter.im/picardy/angular-fontawesome](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/picardy/angular-fontawesome?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

http://picardy.github.io/angular-fontawesome/demo/

A simple directive for [FontAwesome](http://fontawesome.io/) icons. Avoid writing a massive `ngStyle` declaration for your FontAwesome integration, and use the power of Angular to make interactive icon-based widgets.

### Usage

1. Include the FontAwesome CSS and fonts in your application by [following their instructions](http://fortawesome.github.io/Font-Awesome/get-started/).

2. Include the angular-fontawesome module in your Angular app.
    ```javascript
    angular.module('myApp', ['picardy.fontawesome'])
    ```

3. Use the directive on any page which bootstraps your app.
    ```html
    <fa name="spinner" spin ng-style="{'color': checkColor}"></fa>
    <!-- $scope.checkColor = 'blue' -->
    <!-- rendered -->
    <i class="fa fa-spinner fa-spin" style="color:blue;"></i>
    ```

### Attributes

The `fa` directive's attributes map to the classes used by FontAwesome\.

```html
<fa name="ICON-NAME"
    alt="TEXT-ALTERNATIVE"
    size="1-5|large"
    flip="horizontal|vertical"
    rotate="90|180|270"
    spin
    border
    list
></fa>
```

##### name
The icon's [name](http://fontawesome.io/icons/), such as `fa-spinner` or `fa-square`.
```html
<fa name="github"></fa>
<!-- rendered -->
<i class="fa fa-github"></i>
```

##### alt
For accessibility support, you can now add an *alt* attribute, which will add a [screen-reader friendly](https://github.com/FortAwesome/Font-Awesome/issues/6133#issuecomment-88944728) replacement text.
```html
<fa name="github" alt="github website"></fa>
<!-- rendered -->
<i class="fa fa-github" aria-hidden="true"></i>
<span class="sr-only">github website</span>
```

*notice:* the ['sr-only' class](http://getbootstrap.com/css/#helper-classes-screen-readers) will hide the text from anyone not using a screen reader. It is derived from [Bootstrap](http://getbootstrap.com/), so if you're not using Bootstrap, you must add this style to your css:
```css
.sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    margin: -1px;
    padding: 0;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    border: 0;
}
```

##### size
The icon's font size, either defined by a multiplier (1-5), or by the string `"large"`.
```html
<fa name="square" size="{{ currentSize }}"></fa>
<!-- $scope.currentSize = 3 -->
<!-- rendered -->
<i class="fa fa-square fa-3x"></i>
```

##### flip
Flip the icon `horizontal` or `vertical`.
```html
<fa name="pencil" flip="vertical"></fa>
<!-- rendered -->
<i class="fa fa-pencil fa-flip-vertical"></i>
```

##### rotate
Rotate the icon `90`, `180`, or `270` degrees.
```html
<fa name="floppy-o" rotate="90"></fa>
<!-- rendered -->
<i class="fa fa-floppy-o fa-rotate-90"></i>
```

##### spin
Animate the icon to spin. You don't need to provide true to use the boolean attributes:
```html
<fa name="spinner" spin></fa>
<!-- rendered -->
<i class="fa fa-spinner fa-spin"></i>
```
You can pass in `true` or `false` to the attribute as well, allowing the spin class to be be easily toggleable.
```html
<fa name="{{ isLoading ? 'spinner' : 'check' }}" spin="{{ isLoading }}"></fa>
<!-- rendered -->
<i class="fa fa-spinner fa-spin"></i>
```

##### border
```html
<fa name="envelope" border></fa>
<!-- rendered -->
<i class="fa fa-envelope fa-border"></i>
```

##### fixed width
```html
<fa name="book" fw></fa>
<!-- rendered -->
<i class="fa fa-book fa-fw"></i>
```

##### inverse
```html
<fa name="home" inverse></fa>
<!-- rendered -->
<i class="fa fa-home fa-inverse"></i>
```

##### list
This directive autodetects if you're setup to do `fa-li` and then takes care of it for you.
```html
<ul class="fa-ul">
  <li>
    <fa name="square"></fa>
    Text here
    <fa class="check"></fa>
  </li>
</ul>
<!-- rendered -->
<ul class="fa-ul">
  <li>
    <i class="fa fa-li fa-square"></i>
    Text here
    <!-- <fa>s that aren't the first <fa> in the <li> do not automatically get the fa-li class -->
    <i class="fa fa-check"></i>
  </li>
</ul>
```

##### stack
The `faStack` directive is used as a wrapper for stacked fonts used by FontAwesome\.

```html
<fa-stack size="1-5|large">
    <fa name="ICON_NAME" stack="1-5|large"></fa>
    <fa name="ICON_NAME" stack="1-5|large"></fa>    
</fa-stack>
```
When using <fa-stack> as a wrapper, you must also specify the 'stack' attribute on the children,
as described [here](http://fortawesome.github.io/Font-Awesome/examples/#stacked).
Failure to do so will render the fonts, just not one on top of another like we want them to.

### TODO
 * `fa-stack` tests
 * `pull="left"`, `pull="right"`
 * full browser support list

### License
MIT Licensed by [Picardy](http://beta.picardylearning.com).
