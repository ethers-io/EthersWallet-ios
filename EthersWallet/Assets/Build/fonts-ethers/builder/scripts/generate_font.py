# Font generation script from FontCustom
# https://github.com/FontCustom/fontcustom/
# http://fontcustom.com/

import fontforge
import os
import md5
import subprocess
import tempfile
import json
import copy

SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))
INPUT_SVG_DIR = os.path.join(SCRIPT_PATH, '..', '..', 'src')
OUTPUT_FONT_DIR = os.path.join(SCRIPT_PATH, '..', '..', 'fonts')
MANIFEST_PATH = os.path.join(SCRIPT_PATH, '..', 'manifest.json')
AUTO_WIDTH = True
KERNING = 15

f = fontforge.font()
f.encoding = 'UnicodeFull'
f.design_size = 16
f.em = 512
f.ascent = 448
f.descent = 64

font_name = 'ethers'

manifest_data = dict(name = font_name, icons = [])

for dirname, dirnames, filenames in os.walk(INPUT_SVG_DIR):
  for filename in filenames:
    name, ext = os.path.splitext(filename)
    filePath = os.path.join(dirname, filename)
    size = os.path.getsize(filePath)

    if ext in ['.svg', '.eps']:
      chr_code = hex(ord(filename.split('-')[0]))

      print '%s - %s' % (filename, chr_code)

      manifest_data['icons'].append({
        'name': name,
        'code': chr_code
      })

      if ext in ['.svg']:
        # hack removal of <switch> </switch> tags
        svgfile = open(filePath, 'r+')
        tmpsvgfile = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
        svgtext = svgfile.read()
        svgfile.seek(0)

        # replace the <switch> </switch> tags with 'nothing'
        svgtext = svgtext.replace('<switch>', '')
        svgtext = svgtext.replace('</switch>', '')

        tmpsvgfile.file.write(svgtext)

        svgfile.close()
        tmpsvgfile.file.close()

        filePath = tmpsvgfile.name
        # end hack

      glyph = f.createChar(int(chr_code, 16))
      glyph.importOutlines(filePath)

      # if we created a temporary file, let's clean it up
      if tmpsvgfile:
        os.unlink(tmpsvgfile.name)

      # set glyph size explicitly or automatically depending on autowidth
      if AUTO_WIDTH:
        glyph.left_side_bearing = glyph.right_side_bearing = 0
        glyph.round()

    # resize glyphs if autowidth is enabled
    if AUTO_WIDTH:
      f.autoWidth(0, 0, 512)

  fontfile = '%s/ethers' % (OUTPUT_FONT_DIR)

f.fontname = font_name
f.familyname = font_name
f.fullname = font_name
f.generate(fontfile + '.ttf')
f.generate(fontfile + '.svg')

# Fix SVG header for webkit
# from: https://github.com/fontello/font-builder/blob/master/bin/fontconvert.py
svgfile = open(fontfile + '.svg', 'r+')
svgtext = svgfile.read()
svgfile.seek(0)
svgfile.write(svgtext.replace('''<svg>''', '''<svg xmlns="http://www.w3.org/2000/svg">'''))
svgfile.close()

scriptPath = os.path.dirname(os.path.realpath(__file__))
try:
  subprocess.Popen([scriptPath + '/sfnt2woff', fontfile + '.ttf'], stdout=subprocess.PIPE)
except OSError:
  # If the local version of sfnt2woff fails (i.e., on Linux), try to use the
  # global version. This allows us to avoid forcing OS X users to compile
  # sfnt2woff from source, simplifying install.
  subprocess.call(['sfnt2woff', fontfile + '.ttf'])

# eotlitetool.py script to generate IE7-compatible .eot fonts
subprocess.call('python ' + scriptPath + '/eotlitetool.py ' + fontfile + '.ttf -o ' + fontfile + '.eot', shell=True)
subprocess.call('mv ' + fontfile + '.eotlite ' + fontfile + '.eot', shell=True)

# Hint the TTF file
subprocess.call('ttfautohint -s -f -n ' + fontfile + '.ttf ' + fontfile + '-hinted.ttf > /dev/null 2>&1 && mv ' + fontfile + '-hinted.ttf ' + fontfile + '.ttf', shell=True)

manifest_data['icons'] = sorted(manifest_data['icons'], key=lambda k: k['name'])

print "Save Manifest, Icons: %s" % ( len(manifest_data['icons']) )
f = open(MANIFEST_PATH, 'w')
f.write( json.dumps(manifest_data, indent=2, separators=(',', ': ')) )
f.close()

