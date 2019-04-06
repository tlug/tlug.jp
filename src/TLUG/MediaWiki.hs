{-
    MediaWiki transclusion, magic words, and other {{...}} syntax is
    documented not terribly well at:
        https://en.wikipedia.org/wiki/Wikipedia:Transclusion
        https://www.mediawiki.org/wiki/Transclusion

    Transcludes appear to be done before parsing the markup, so the
    parsing is done on a complete page that's the concatenation of the
    transcluded markup and intervening markup from the original page.

    Summary:
    - {{Foo:Bar}}: Substitute contents of `Templates:Foo:Bar` page.
    - {{:Foo:Bar}}: Substitute contents of `Foo:Bar` page.
    - {{Foo|baz|quux}}: Subsitute with positional parameters `baz` and `quux`.
    - {{Foo|foo=bar}}: Substitute with named parameter `foo` valued `bar`.
    - {{Foo Bar|a pos param|named param=other text}}: Spaces in names/params.

    "Magic words" look the same but are distinguished by being somehow
    defined as such, and use a colon to start the arguments:
    - {{FULLPAGENAME}}
    - {{FULLPAGENAME:A different name}}
    - {{subst:OtherPage}}

    Some magic words have templates that call the magic word:
    - {{FULLPAGENAME|A different name}}

    Tags affecting transclusion:
    - <noinclude>:   Not rendered when transcluded.
    - <onlyinclude>: Everything but this rendered when transcluded.
    - <includeonly>: Don't even ask.

    There's much more; hopefully we won't need to handle too much of
    it for the TLUG pages.
-}
module TLUG.MediaWiki
    ( Page, Chunk(..)
    , parsePage
    ) where


type Page = [Chunk]

data Chunk
    = Markup String
    | Transclude
      { pageName :: String
      , params   :: [String]
      }
    deriving (Show, Eq)

parsePage :: String -> Page
parsePage s = parse [] s

type Accum = String
type Remainder = String

parse :: Accum -> Remainder -> [Chunk]
parse acc "" = [Markup $ reverse acc]
parse acc (x:xs) = parse (x:acc) xs
