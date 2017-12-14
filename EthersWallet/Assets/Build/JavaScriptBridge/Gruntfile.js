'use strict';

module.exports = function(grunt) {
  grunt.initConfig({
    browserify: {
      library: {
        files: {
          '../../JavaScript/ethers-web3.js': [ 'index.js' ],
        },
        options: {
          /*
          transform: [
            { global: true },
          ],
          */
          browserifyOptions: {
            //standalone: 'ethers'
            detectGlobals: true
          },
          //preBundleCB: preBundle,
          //postBundleCB: postBundle
        }
      },
    },
    uglify: {
      dist: {
        files: {
          '../../JavaScript/ethers-web3.min.js' : [ '../../JavaScript/ethers-web3.js' ],
        }
      }
    }
  });

  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-contrib-uglify');

  grunt.registerTask('dist', ['browserify', 'uglify']);
};

