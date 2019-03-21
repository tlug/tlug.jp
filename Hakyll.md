Hakyll Notes
============

Documentation
-------------

- [Tutorial: A Guide to the Hakyll Module Zoo][module zoo] provides an
  overview of the modules typically used by developers of site
  compilers (as opposed to internal modules used those hacking on
  Hakyll itself).
- The [Hakyll reference] is the Haddock-generated documentation with
  links to the source code.


Overview
--------

The `hakyll` function takes a set of rules (routes and compilers)  to
produce the site. These are built in the [`Rules`] monad via functions
such as `match`, `create`, `route`, and `compile`.

Items
-----

The compilation stages are a pipeline that transforms `Item`s, which
are basically a path and a typed body (`String`, `Pandoc`, etc.).

- From `Hakyll.Core`
  - `Item a = Item { itemidentifier :: Identifier, itemBody a }`
  - `Identifier = Identifier`  
    `{ identifierVersion :: Maybe String, identifierPath :: String}`


Routes
------

* Output paths are not tracked; if you have two different things
  routing to the same output path the later one will overwrite the
  earlier one.


Compilers
---------

### Metadata

YAML metadata in files appears to be handled by Pandoc, not by Hakyll.
Pandoc has a [`yaml_metadata_block`] extension that reads blocks
delimited by `---` and `---`/`...`. Blocks not at the beginning of the
document must be preceded by a blank line. Settings in earlier blocks
take priority over those in later blocks. String scalars in the
metadata are interpreted as Markdown.

In Pandoc world the metadata can be used in Pandoc's templating
engine, but Hakyll provides its own templating engine (with almost the
same syntax as Pandoc's), `Hakyll.Web.Template` which uses this
metadata.

`Hakyll.Web.Pandoc` contains the various Pandoc-related functions;
including:
* `.pandocCompilerWithTransform`: Allows manipulating the Pandoc AST
  between reading and writing.



<!-------------------------------------------------------------------->
[Hakyll reference]: https://jaspervdj.be/hakyll/reference/index.html
[module zoo]: https://jaspervdj.be/hakyll/tutorials/a-guide-to-the-hakyll-module-zoo.html
[`yaml_metadata_block`]: https://pandoc.org/MANUAL.html#extension-yaml_metadata_block
