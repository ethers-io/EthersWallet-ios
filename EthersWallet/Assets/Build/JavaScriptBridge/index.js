(function(window) {

    var sendWeb3Message = function(action, params, callback) {
        console.log('<<<', action, params);
    }

    var network = '__ETHERS_NETWORK__';

    // Note: web3 removes the checksum and converts this to lowercase for accounts
    var defaultAccount = ('__ETHERS_DEFAULT_ACCOUNT__' || null);

    if (window && window.webkit && window.webkit.messageHandlers) {
        // Create the "parent" window which will broadcastmessages to Ethers Wallet
        (function() {
            var ethers = window.webkit.messageHandlers.Ethers;

            function Window() {
                Object.defineProperty(this, 'isEthers', {
                    enumerable: true,
                    value: true,
                    writable: false
                });
            }

            Object.defineProperty(Window.prototype, 'postMessage', {
                enumerable: true,
                value: function(message) {
                    ethers.postMessage(message);
                },
                writable: false
            });

            var mockParent = new Window();

            Object.defineProperty(window, 'parent', {
                enumerable: false,
                value: mockParent,
                writable: false
            });

            Object.defineProperty(window.parent, '_respondEthers', {
                enumerable: true,
                value: function(result) {
                    window.postMessage(result, '*');
                    return 'ok';
                },
                writable: false
            });
        })();

        // console support
        (function() {

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
                            if (object === null) { return 'null'; }

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
            var oldConsole = window.console;

            // The console object
            var console = {};
            Object.defineProperty(window, 'console1', {
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
                    window.parent.postMessage({action: "console.log", message: message.join(', ')});
                }
            });

            // TODO: Maybe wrap these up nicer?
            console.error = console.log;
            console.warn = console.log;

            //console.log(oldConsole);

        })();



        (function() {
            var ethersWeb3 = window.webkit.messageHandlers.Web3;

            var nextMessageId = 1;

            var callbacks = {};

            Object.defineProperty(window.parent, '_respondWeb3', {
                enumerable: true,
                value: function(result) {
                    var callback = callbacks[result.id];
                    if (callback) {
                        setTimeout(function() {
                            callback(null, result.result);
                        }, 0)
                        delete callbacks[result.id];
                    }
                    return 'ok';
                },
                writable: false
            });

            sendWeb3Message = function(action, params, callback) {
                var messageId = nextMessageId++;
                var payload = {
                    action: action,
                    ethers: 'v\x01\n',
                    id: messageId,
                    params: params,
                };
                if (callback) {
                    callbacks[messageId] = callback;
                }
                ethersWeb3.postMessage(payload, '*');
            }

        })();

        // Make CryptoKitties work (remove this in the future)
        window.chrome = { webstore: true };

        //
        window.addEventListener('error', function(error) {
            console.log('ERROR', arguments);
        });

        setInterval(function() {
            for (var i = 0; i < localStorage.length; i++){
                // do something with localStorage.getItem(localStorage.key(i));
                var key = localStorage.key(i);
                console.log('LS', key, localStorage.getItem(key));
            }
        }, 5000);
    }

    var providers = require('ethers-providers');
    var utils = require('ethers-utils');

    var provider = providers.getDefaultProvider(network);


    // Convert a Web3 Transaction into an ethers.js Transaction
    function makeTransaction(tx) {
        var result = {};
        ['data', 'from', 'gasPrice', 'to', 'value'].forEach(function(key) {
            if (tx[key] == null) { return; }
            result[key] = tx[key];
        });
        if (tx.gas != null) { result.gasLimit = tx.gas; }

        return result;
    }

    // Convert ethers.js Block into Web3 Block
    function formatBlock(block) {
        var result = {};

        // Things to provide compact values for
        ['difficulty', 'gasLimit', 'gasUsed', 'number', 'timestamp'].forEach(function(key) {
            if (block[key] == null) { return; }
            result[key] = smallHexlify(block[key]);
         });

         // Things to copy
         ['extraData', 'miner', 'parentHash'].forEach(function(key) {
             if (block[key] == null) { return; }
             result[key] = block[key];
         });

         // Things to provide compact values for (or set to null)
         ['number'].forEach(function(key) {
             result[key] = ((block[key] != null) ? smallHexlify(block[key]): null);
         });

         // Things to copy (or set to null)
         ['hash', 'nonce'].forEach(function(key) {
             result[key] = (block[key] || null);
         });

         return result;
    }

    // Convert ethers.js Transaction into Web3 Transaction
    function formatTransaction(tx) {
        var result = {};

        if (tx.gasLimit) { result.gas = smallHexlify(tx.gasLimit); }
        result.input = (tx.data || '0x');

        // Things to provide compact values for
        ['blockNumber', 'gasPrice', 'nonce', 'transactionIndex', 'value'].forEach(function(key) {
            result[key] = ((block[key] != null) ? smallHexlify(block[key]): null);
        });

        // Things to copy
        ['blockHash', 'from', 'hash', 'to'].forEach(function(key) {
            result[key] = (block[key] || null);
        });

        return result;
    }

    // Convert ethers.js Log into Web3 Log
    function formatLog(log) {
        var result = {};
        ['blockNumber', 'logIndex', 'transactionIndex'].forEach(function(key) {
            if (log[key] == null) { return; }
            result[key] = smallHexlify(log[key]);
        });
        ['address', 'blockHash', 'data', 'topics', 'transactionHash'].forEach(function(key) {
            if (log[key] == null) { return; }
            result[key] = log[key];
        });
        return log;
    }

    function now() {
        return (new Date()).getTime();
    }

    function makeError(message, params) {
        var error = new Error(message);
        for (var key in params) {
            error
        }

        try {
            throw new Error('stack capture');
        } catch (e) {
            error.stack = e.stack;
        }

        return error;
    }

    // Some implementations of things do not play well with leading zeros
    function smallHexlify(value) {
        value = utils.hexlify(value)
        while (value.length > 3 && value.substring(0, 3) === '0x0') {
            value = '0x' + value.substring(3);
        }
        return value;
    }

    function FilterManager() {
        utils.defineProperty(this, 'filters', {});

        var nextFilterId = 1;
        utils.defineProperty(this, '_getFilterId', function() {
            return nextFilterId++;
        });
    }

    FilterManager.prototype.addFilter = function(onblock, getLogs) {
        if (!getLogs) { getLogs = function() { return Promise.resolve([]); } }

        var filterId = this._getFilterId();

        var seq = Promise.resolve([]);

        function emitBlock(blockNumber) {
            seq = seq.then(function(result) {
                return new Promise(function(resolve, reject) {
                    function check() {
                        provider.getBlock(blockNumber).then(function(block) {
                            onblock(block, result).then(function(result) {
                                resolve(result);
                            });
                        }, function (error) {
                            // Does not exist yet; try again in a second
                            setTimeout(check, 1000);
                        });
                    }
                    check();
                });
            });
        }

        this.filters[smallHexlify(filterId)] = {
            getChanges: function() {
                var result = seq;

                // Reset the filter results
                seq = Promise.resolve([]);
                return result;
            },
            getLogs: getLogs,
            lastPoll: now(),
            uninstall: function() {
                provider.removeListener('block', emitBlock);
                seq = null;
            }
        };

        provider.on('block', emitBlock);

        return smallHexlify(filterId);
    }

    FilterManager.prototype.removeFilter = function(filterId) {
        var filter = this.filters[smallHexlify(filterId)];
        if (!filter) { return false; }
        filter.uninstall();
        return true;
    }

    FilterManager.prototype.getChanges = function(filterId) {
        var filter = this.filters[smallHexlify(filterId)];
        if (!filter) { Promise.resolve([]); }
        return filter.getChanges();
    }

    FilterManager.prototype.getLogs = function(filterId) {
        var filter = this.filters[smallHexlify(filterId)];
        if (!filter) { return Promise.resolve([]); }
        return filter.getLogs();
    }


    function EthersBridgeProvider() {
        utils.defineProperty(this, 'isMetaMask', true);
        utils.defineProperty(this, 'isEthers', true);
        utils.defineProperty(this, 'ethersVersion', '$$_REPLACE_VERSION_$$');

        utils.defineProperty(this, 'filterManager', new FilterManager());
    }

    EthersBridgeProvider.isConnected = function() {
        // @TODO: chat with the app
        return true;
    }

    var Errors = {
        InternalError:    -32603,
        InvalidRequest:   -32600,
        ParseError:       -32700,
        MethodNotFound:   -32601,
        InvalidParams:    -32602,
    };

    EthersBridgeProvider.prototype.sendAsync = function(payload, callback) {
        var self = this;

        if (Array.isArray(payload)) {

            var promises = [];
            payload.forEach(function(payload) {
                promises.push(new Promise(function(resolve, reject) {
                    self.sendAsync(payload, function(error, result) {
                        resolve(error || result);
                    });
                }));
            });

            Promise.all(promises).then(function(result) {
                callback(null, result);
            });

            return;
        }


        function respondError(message, code) {
            if (!code) { code = Errors.InternalError; }

            callback(null, {
                id: payload.id,
                jsonrpc: "2.0",
                error: {
                    code: code,
                    message: message
                }
            });
        }

        function respond(result) {
            callback(null, {
                id: payload.id,
                jsonrpc: "2.0",
                result: result
            });
        }

        if (payload == null || typeof(payload.method) !== 'string' || typeof(payload.id) !== 'number' || !Array.isArray(payload.params)) {
            console.log('MockWeb3 - unknown payload', payload);
            respondError('invalid sendAsync parameters', Errors.InvalidRequest);
            return;
        }

        var params = payload.params;
        switch (payload.method) {

            // Account Actions

            case 'eth_accounts':
                sendWeb3Message('getAccount', { }, function(error, account) {
                    if (account) {
                        respond([ account.toLowerCase() ]);
                    } else {
                        respond([]);
                    }
                });
                break;

            case 'personal_sign':
            /*
                (function() {
                    var message = params[0];
                    var address = params[1];
                    var password = params[2];
                    params = [address, message];
                })();
                */
                // Fall-through

            //case 'eth_sign':
                try {
                    if (utils.getAddress(params[1]) !== defaultAccount) {
                        throw new Error('address not managed by this instance');
                    }
                } catch (error) {
                    console.log(error);
                    respondError('invalid from address', Errors.InvalidParams);
                    break;
                }

                sendWeb3Message('signMessage', {
                    //message: utils.hexlify(utils.toUtf8Bytes(params[1]))
                    message: params[0]
                }, function(error, signature) {
                    if (error) {
                        console.log(error);
                        respondError('eth_sign error', Errors.InternalError);
                    } else {
                        console.log('GOT', signature);
                        respond(signature);
                    }
                });
                break;

            case 'eth_sendTransaction':
                try {
                    if (utils.getAddress(params[0].from) !== defaultAccount) {
                        throw new Error('address not managed by this instance');
                    }
                } catch (error) {
                    console.log(error);
                    respondError('invalid from address', Errors.InvalidParams);
                    break;
                }

                sendWeb3Message('sendTransaction', {
                    transaction: params[0]
                }, function(error, transaction) {
                    if (error) {
                        console.log(error);
                        respondError('eth_sendTransaction error', Errors.InternalError);
                    } else {
                        respond(transaction.hash);
                    }
                });
                break;


            // Client State (mostly just default values we can pull from sync)

            case 'eth_coinbase':
            case 'eth_getCompilers':
            case 'eth_hashrate':
            case 'eth_mining':
            case 'eth_syncing':
            case 'net_listening':
            case 'net_peerCount':
            case 'net_version':
            case 'eth_protocolVersion':
                setTimeout(function() {
                    respond(self.send(payload).result);
                }, 0);
                break;

            // Blockchain state

            case 'eth_blockNumber':
                provider.getBlockNumber().then(function(blockNumber) {
                    respond(smallHexlify(blockNumber));
                });
                break;

            case 'eth_gasPrice':
                provider.getGasPrice().then(function(gasPrice) {
                    respond(smallHexlify(gasPrice));
                });
                break;


            // Accounts Actions

            case 'eth_getBalance':
                provider.getBalance(params[0], params[1]).then(function(balance) {
                    respond(smallHexlify(balance));
                });
                break;

            case 'eth_getCode':
                provider.getCode(params[0], params[1]).then(function(code) {
                    respond(code);
                });
                break;

            case 'eth_getTransactionCount':
                provider.getTransactionCount(params[0], params[1]).then(function(nonce) {
                    respond(smallHexlify(nonce));
                });
                break;


            // Execution (read-only)

            case 'eth_call':
                provider.call(makeTransaction(params[0]), params[1]).then(function(data) {
                    respond(data);
                });
                break;

            case 'eth_estimateGas':
                provider.call(makeTransaction(params[0]), params[1]).then(function(data) {
                    respond(data);
                });
                break;

            case 'eth_getStorageAt':
                provider.getStorageAt(params[0], params[1], params[2]).then(function(data) {
                    respond(data);
                });
                break;


            // Blockchain Queries

            case 'eth_getBlockByHash':
            case 'eth_getBlockByNumber':
                provider.getBlock(params[0]).then(function(block) {
                    var result = formatBlock(block);

                    if (params[1]) {
                        result.transactions = [];

                        var seq = Promise.resolve();

                        if (block.transactions) {
                            block.transactions.forEach(function(hash) {
                                return provider.getTransaction(hash).then(function(tx) {
                                    result.transactions.push(tx);
                                });
                            });
                        }

                        seq.then(function() {
                            respond(result);
                        });

                    } else {
                        if (block.transactions) { result.transactions = block.transactions; }
                        respond(result);
                    }
                });
                break;

            case 'eth_getBlockTransactionCountByHash':
            case 'eth_getBlockTransactionCountByNumber':
                provider.getBlock(params[0]).then(function(block) {
                    respond(smallHexlify(block.transactions ? block.transactions.length: 0));
                });
                break;

            case 'eth_getTransactionByHash':
                provider.getTransaction(params[0]).then(function(tx) {
                    if (tx != null) { tx = formatTransaction(tx); }
                    respond(tx);
                });
                break;

            case 'eth_getTransactionByBlockHashAndIndex':
            case 'eth_getTransactionByBlockNumberAndIndex':
                provider.getBlock(params[0]).then(function(block) {
                    if (block == null) { block = {}; }
                    if (block.transactions == null) { block.transactions = []; }
                    var hash = block.transactions[params[1]];
                    if (hash) {
                        provider.getTransaction(hash).then(function(tx) {
                            if (tx != null) { tx = formatTransaction(tx); }
                            respond(tx);
                        });
                    } else {
                        respond(null);
                    }
                });
                break;

            case 'eth_getTransactionReceipt':
                provider.getTransactionReceipt(params[0]).then(function(tx) {
                    console.log('@TODO');
                    respond(tx);
                });
                break;


            // Blockchain Manipulation

            case 'eth_sendRawTransaction':
                provider.sendTransaction(params[0]).then(function(hash) {
                    respond(hash);
                });
                break;


            // Unsupported methods
            case 'eth_getUncleByBlockHashAndIndex':
            case 'eth_getUncleByBlockNumberAndIndex':

            case 'eth_getUncleCountByBlockHash':
            case 'eth_getUncleCountByBlockNumber':
                respondError('unsupported method', { method: payload.method });
                break;

            case 'eth_newFilter':
                (function(filter) {
                    function getLogs(filter) {
                        return provider.getLogs(filter).then(function(result) {
                            for (var i = 0; i < result.length; i++) {
                                result[i] = formatLog(result[i]);
                            }
                            return result;
                        });
                    }

                    respond(self.filterManager.addFilter(function(block, result) {
                        var blockFilter = {
                            fromBlock: block.number,
                            toBlock: block.number
                        }
                        if (filter.address) { blockFilter.address = filter.address; }
                        if (filter.topics) { blockFilter.topics = filter.topics; }
                        return provider.getLogs(blockFilter).then(function(logs) {
                            logs.forEach(function(log) {
                                log.blockHash = block.hash;
                                result.push(formatLog(log));
                            });
                            return result;
                        });

                    }, function() {
                        return provider.getLogs(filter).then(function(logs) {
                            var seq = Promise.resolve(logs);
                            logs.forEach(function(log) {
                                seq = seq.then(function() {
                                    return provider.getBlock(log.blockNumber).then(function(block) {
                                        log.blockHash = block.hash;
                                        return logs;
                                    });
                                });
                            });
                            return seq;
                        });
                    }));
                })(params[0]);
                break;

            case 'eth_newPendingTransactionFilter':
                respond(this.filterManager.addFilter(function(block, result) {
                    (block.transactions || []).forEach(function(hash) {
                         result.push(hash);
                    });
                    result.push(block.hash);
                    return Promise.resolve(result);
                }));
                break;

            case 'eth_newBlockFilter':
                respond(this.filterManager.addFilter(function(block, result) {
                    result.push(block.hash);
                    return Promise.resolve(result);
                }));
                break;

            case 'eth_uninstallFilter':
                respond(this.filterManager.removeFilter(params[0]));
                break;

            case 'eth_getFilterChanges':
                this.filterManager.getChanges(params[0]).then(function(result) {
                    respond(result);
                });
                break;

            case 'eth_getFilterLogs':
                this.filterManager.getLogs(params[0]).then(function(result) {
                    respond(result);
                });
                break;


            default:
                console.log('MockWeb3 - Unknown Async:', payload);
                respondError('unknown method', Errors.MethodNotFound);
        }
    }

    EthersBridgeProvider.prototype.send = function(payload) {
        var result = null;
        switch(payload.method) {
            case 'eth_accounts':
                result = [ defaultAccount.toLowerCase() ];
                break;

            case 'eth_coinbase':
                result = null;
                break;

            case 'eth_getCompilers':
                result = [];
                break;

            case 'eth_hashrate':
            case 'net_peerCount':
                result = "0x0";
                break;

            case 'eth_mining':
            case 'eth_syncing':
            case 'net_listening':
                result = false;
                break;

            case 'net_version':
                result = String(providers.Provider.chainId[network]);
                break;

            // @TODO: What should this be??
            case 'eth_protocolVersion':
                result = "54";
                break;

            default:
                console.log('MockWeb3 - unknown sync:', payload);
                throw new Error('sync unsupported');
        }

        return {
            id: payload.id,
            jsonrpc: "2.0",
            result: result
        };
    }

    window.web3 = { };

    var currentProvider = null;

    Object.defineProperty(web3, 'currentProvider', {
        configurable: true,
        enumerable: true,
        get: function() {
            if (currentProvider == null) {
                console.log('Web3 currentProvider created');
                currentProvider = new EthersBridgeProvider();
            }
            return currentProvider;
        },
        set: function(value) {
            console.log('Warning: Replacing currentProvider - not recommended');
            currentProvider = value;
        }
    });

    console.log('Network: ' + network);
    throw new Error('goof');
})(global);
