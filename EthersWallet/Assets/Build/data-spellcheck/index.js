'use strict';

var fs = require('fs');
var tipo = require('tipo');
var bip39 = require('bip39')

// http://www.tysto.com/uk-us-spelling-list.html
function getLines(filename) {
    var lines = [];

    var html = fs.readFileSync(filename);
    html = html.toString().replace(/<br>/g, '')
               .replace(/ |(^ *\n$)/g, '').replace(/<[^>]*>/g, '')
               .split('\n');
    html.forEach(function(line) {
        line = line.trim();
        if (!line) { return; }
        lines.push(line);
    });
    return lines;
}

var alts = {};

var htmlA = getLines('spelling-a.html');
var htmlB = getLines('spelling-b.html');
for (var i = 0; i < htmlA.length; i++) {
    var a = htmlA[i], b = htmlB[i];

    // US English first...
    if (!alts[b]) { alts[b] = []; }
    alts[b].push(a);

    // The rest of the world
    if (!alts[a]) { alts[a] = []; }
    alts[a].push(b);
}

var lookup = {};
var typos = require('./node_modules/misspellings/dict/lc-dictionary.json');
for (var typo in typos) {
    var word = typos[typo];
    if (!lookup[word]) { lookup[word] = []; }
    lookup[word].push(typo);
}

var wordlist = bip39.wordlists.EN;
wordlist.forEach(function(word) {
    if (alts[word]) {
        console.log('ALT', word, alts[word]);
    }
    if (lookup[word]) {
        console.log('TYPO', word, lookup[word]);
    }
});

function getTypos(word) {
    var typos = {};
    typos[word] = true;

    (alts[word] || []).forEach(function(typo) {
        typos[typo] = true;
    });

    (lookup[word] || []).forEach(function(typo) {
        typos[typo] = true;
    });

    tipo.getKeyboardMissTypos(word).forEach(function(typo) {
        typos[typo] = true;
    });
    /*
    tipo.getMissingLetterTypos(word).forEach(function(typo) {
        typos[typo] = true;
    });
    tipo.getMixedLetterTypos(word).forEach(function(typo) {
        typos[typo] = true;
    });
    */
    return Object.keys(typos);
}

var mapping = {};

var wordlist = bip39.wordlists.EN;
wordlist.forEach(function(word) {
    getTypos(word).forEach(function(typo, weight) {
        for (var i = 1; i <= typo.length; i++) {
            var prefix = typo.substring(0, i);
            if (!mapping[prefix]) { mapping[prefix] = {}; }
            mapping[prefix][word] = weight;
        }
    });
});

var counts = {};
for (var prefix in mapping) {
    var weights = mapping[prefix];
    mapping[prefix] = Object.keys(weights);
    mapping[prefix].sort(function(a, b) {
        if (a === prefix) { return -1000; }
        if (b === prefix) { return 1000; }
        return (weights[b] - weights[a]);
    });
    counts[prefix] = mapping[prefix].length;
}

for (var prefix in mapping) {
    if (prefix.length === 1) { continue; }
    if (counts[prefix.substring(0, prefix.length - 1)] === 1) {
        //delete mapping[prefix];
    } else if (prefix.match(/[0-9]/)) {
        delete mapping[prefix];
    }
}

console.log(mapping);
fs.writeFileSync('../../Data/spellcheck.json', JSON.stringify(mapping));
