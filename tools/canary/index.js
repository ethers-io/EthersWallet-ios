/**
 *  Canary
 *
 *  The canary file can be uploaded to https://ethers.io/canary.raw
 *  in the event a serious bug is discovered that users must be warned
 *  of.
 *
 *  It must be signed with the private key for the address:
 *
 *      0x70C14080922f091fD7d0E891eB483C9f8464a527
 *
 *  TODO: This needs to be updated to take a secure password from
 *        readlineSync rather than the command line.
 */

var crypto = require('crypto');
var fs = require('fs');

var Wallet = require('ethers-wallet');

var jsonFilename = process.argv[2];
var password = process.argv[3];
var canaryFilename = process.argv[4];

var canaryData = fs.readFileSync(canaryFilename);
canaryData = JSON.stringify(JSON.parse(canaryData));

var transaction = {
    nonce: '0x00',
    gasPrice: '0x00',
    gasLimit: '0x00',
    value: '0x00',
    data: (new Buffer(canaryData)),
}


Wallet.decrypt(fs.readFileSync(jsonFilename), new Buffer(password)).then(function(wallet) {
    var data = wallet.sign(transaction);
    var hash = crypto.createHash('sha256').update(new Buffer(data.substring(2), 'hex')).digest()

    console.log('Address:     ' + wallet.address);
    console.log('Hash:        0x' + hash.toString('hex'));
    console.log('Filename:    canary-' + hash.slice(0, 4).toString('hex') + '.hex');
    console.log('Data:        ' + data);

}, function(error) {
    console.log(error);
});
