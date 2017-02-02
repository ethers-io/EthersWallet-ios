#!/bin/bash

rm -rf fonts/ethers.ttf
fontforge -script $PWD/builder/scripts/generate_font.py
cp ./fonts/ethers.ttf ../../Fonts/ethers.ttf
