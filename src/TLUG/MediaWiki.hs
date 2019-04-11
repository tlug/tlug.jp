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
    , runParser, char,
    ) where

import Control.Applicative;

type Page = [Chunk]

type ParamList = [(String,String)]
data Chunk
    = Markup String
    | Transclude
      { pageName :: String
      , params   :: ParamList
      }
    | TestChunk Char
    deriving (Show, Eq)

parsePage :: String -> Page
parsePage s = runParser chunks s

data ParserState = ParserState
    { remaining :: String
    }
newtype Parser a = Parser { unParser :: (ParserState -> Maybe (a, ParserState)) }

instance Functor Parser where
    -- fmap :: (a -> b) -> Parser a -> Parser b
    fmap abFunc (Parser aParser) = Parser (
        \aState -> case aParser aState of
            Nothing -> Nothing
            Just (aResult, bState) -> Just (abFunc aResult, bState)
        )

instance Applicative Parser where
    -- pure :: a -> Parser a
    pure x = Parser $ \state -> Just (x, state)
    -- <*> :: Parser (a -> b) -> Parser a -> Parser b
    (Parser abParser) <*> aParser = Parser (
        \aState -> case abParser aState of
            Nothing -> Nothing
            Just (abFunc, bState) -> unParser (fmap abFunc aParser) bState
        )

instance Alternative Parser where
    -- empty :: f a
    empty = Parser $ return Nothing
    -- (<|>) :: f a -> f a -> f a
    (Parser a) <|> (Parser b) = Parser (
        \state -> case a state of
            Nothing -> b state
            x -> x
        )

instance Monad Parser where
    -- (>>=) :: Parser a -> (a -> Parser b) -> Parser b
    (>>=) aParser a2bFunc = Parser (
        \aState -> case unParser aParser aState of
            Nothing -> Nothing
            Just (aResult, bState) -> unParser (a2bFunc aResult) bState
        )

runParser :: Parser a -> String -> a
runParser (Parser f) s =
    case f (ParserState s) of
        Nothing                  -> error "Parse failed"
        Just (x, ParserState "") -> x
        otherwise                -> error "Incomplete parse"

-- Just for a test? Maybe we don't really need this.
char :: Parser Char
char = Parser (\state ->
            case (remaining state) of
                ""       -> Nothing
                (c:cs)   -> Just (c, ParserState cs)
              )

chunks :: Parser [Chunk]
chunks = many chunk

chunk :: Parser Chunk
chunk = Markup <$> some char
