#!/bin/bash

#/usr/bin/git checkout -- builder/*.json

#/usr/bin/python ./builder/generate.py
#/bin/cp css/* ../website/css/
#/bin/cp fonts/* ../website/fonts/

rm -rf fonts/*.ttf
fontforge -script $PWD/builder/scripts/generate_font.py
cp ./fonts/ethers.ttf ../../Fonts/ethers.ttf
