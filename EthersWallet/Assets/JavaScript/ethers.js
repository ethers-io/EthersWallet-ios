(function(_this) {
    var ethers = window.webkit.messageHandlers.ethers;

    function Window() {
        Object.defineProperty(Window.prototype, 'postMessage', {
            enumerable: true,
            value: function(message) {
                ethers.postMessage(message);
            },
            writable: false
        });

        Object.defineProperty(Window.prototype, '_ethersRespond', {
            enumerable: true,
            value: function(result) {
                window.postMessage(result, '*');
                return 'ok';
            },
            writable: false
        });
    }

    var mockParent = new Window();

    Object.defineProperty(_this, 'parent', {
        enumerable: false,
        value: mockParent,
        writable: false
    });


    // Serialize for console.log
    function serialize(object, path, done) {
        if (path == null) { path = ''; }
        if (!done) { done = {}; }
 
        switch (typeof(object)) {
            case 'string':
            case 'number':
            case 'boolean':
                return JSON.stringify(object);

            case 'undefined':
                return 'undefined';

            case 'function':
                return object.toString();

            case 'object':
                return (function() {

                    var result = [];
                    Object.getOwnPropertyNames(object).forEach(function(key) {
                        var obj = object[key];

                        if (done[obj]) {
                            result.push('[identical reference: ' + done[obj] + ']');

                        } else {
                            var keyPath = path + '/' + key;
                            done[obj] = keyPath;
                            result.push(key + ': ' + serialize(object[key], keyPath, done));
                        }
                    });

                    return '{' + result.join(', ') + '}';
                })();
                break;

            default:
                return '[unhandled type: ' + typeof(object) + ']';
        }
    }

    // The console object
    var console = {};
    Object.defineProperty(_this, 'console', {
        enumerable: true,
        value: console,
        writable: false
    });


    Object.defineProperty(console, 'log', {
        enumerable: true,
        value: function() {
            var message = [];
            Array.prototype.forEach.call(arguments, function(arg) {
                message.push(serialize(arg));
            });
            //mockParent.postMessage({action: "console.log", message: message.join(', ')});
            ethers.postMessage({action: "console.log", message: message.join(', ')});
        }
    });

    // TODO: Maybe wrap these up nicer?
    console.error = console.log;
    console.warn = console.log;
})(this);

