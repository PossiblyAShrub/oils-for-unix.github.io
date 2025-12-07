#!/usr/bin/env ysh
#
# Usage:
#   ./wiki.sh build
#
# This will clone the oils-for-unix/oils wiki, and build all of the markdown
# files using doc tools. The docs are saved to wiki/.
#
# This can be used for the dev guide which is located at wiki/Dev-Guide.html.

const HTML_BASE_DIR = 'wiki/'
const WIKI_DIR = '_tmp/wiki'

proc clone-wiki() {
  if test -d $WIKI_DIR {
    echo "Wiki already cloned to $WIKI_DIR, pulling latest"

    cd $WIKI_DIR {
      git pull
    }

    return
  }

  echo "Cloning wiki to $WIKI_DIR"
  mkdir -p $WIKI_DIR
  git clone https://github.com/oils-for-unix/oils.wiki.git $WIKI_DIR
}

proc remove-wiki() {
  ## Used in CI so the wiki md files are not served under pages.oils.pub
  rm -rf $WIKI_DIR
}

func slugify(s) {
  return (s.replace(" ", "-").replace(",", " "))
}

proc pre-render-wikilinks() {
  ## GitHub wikis have a unique [[link syntax]] which references topic within
  ## the wiki.
  ##
  ## This function converts that syntax to the traditional
  ## [link syntax](./link-syntax.html) which will render correctly once fed to
  ## doctools.
  for line in (io.stdin) {
    var mdlink = line.replace(/ '[[' <capture ![']']* as link> ']]' /,
                              ^"[$link]($[slugify(link)].html)")
    write -- $[mdlink]
  }
}

proc build-one(path) {
  mkdir -p $HTML_BASE_DIR

  var name = path.replace(/ %start dot* '/' <capture dot* as name> '.md' /, ^"$[slugify(name)]")
  var title = name.replace('-', ' ')
  var dest = "$HTML_BASE_DIR/$name.html"

  fopen >$dest {
    echo """
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>$title</title>
          <link rel="stylesheet" type="text/css" href="/web/base.css" />
        </head>
        <body class="width40">
    """

    pre-render-wikilinks <$path | cmark

    echo """
      <div id="build-timestamp">
        <i>Generated on $(date --rfc-email)</i>
      </div>

      </body>
    </html>
    """
  }

  : '''
  ... build/doc.sh render-only
    <(pre-render-wikilinks <$path)
    $HTML_BASE_DIR/$name.html
    "$web_url/base.css $web_url/manual.css $web_url/toc.css $web_url/language.css $web_url/code.css"
    $title
  ;
  '''
}

proc build() {
  clone-wiki
  find $WIKI_DIR -name '*.md' -print0 | xargs -I {} -0 -- $0 build-one {}
}

runproc @ARGV
