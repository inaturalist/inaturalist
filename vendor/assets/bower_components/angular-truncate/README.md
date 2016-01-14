Angular Truncate
---------
This project is a filter for Angularjs to truncate text strings to a set number of characters or words and
add ellipses when needed.

[Demo](http://sparkalow.github.io/angular-truncate/)

## How to use angular truncate


###Include the javascript file.

``` html
<script src="truncate.js"></script>
```

###Inject the `truncate` filter into your app module.

```javascript
var myApp = angular.module('myApp', ['truncate']);
```

###When outputting text, apply the filter.
```html
 <p>
    {{ text | characters:25 }} or {{ text | words:5 }}
</p>
```

By default, a _word_ will not be truncated. Set the optional boolean after the character count to true.
```html
 <p>
     {{ text | characters:25 :true}}
 </p>
 ```