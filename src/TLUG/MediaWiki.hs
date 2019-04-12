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

{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE TupleSections #-}

module TLUG.MediaWiki
    ( Page, Chunk(..)
    , parsePage
    , runParser, anyChar,
    ) where

import Control.Applicative;
import Data.List;

{-
    This is a simple monadic parser framework.
-}

data ParserState = ParserState
    { remaining :: String
    }
newtype Parser a = Parser { parse :: (ParserState -> Maybe (a, ParserState)) }

instance Functor Parser where
    fmap :: (a -> b) -> Parser a -> Parser b
    fmap abFunc (Parser aParser) = Parser (
        \aState -> case aParser aState of
            Nothing -> Nothing
            Just (aResult, bState) -> Just (abFunc aResult, bState)
        )

instance Applicative Parser where
    pure :: a -> Parser a
    pure x = Parser $ \state -> Just (x, state)
    (<*>) :: Parser (a -> b) -> Parser a -> Parser b
    (Parser abParser) <*> aParser = Parser (
        \aState -> case abParser aState of
            Nothing -> Nothing
            Just (abFunc, bState) -> parse (fmap abFunc aParser) bState
        )

instance Alternative Parser where
    empty :: Parser a
    empty = Parser $ return Nothing
    (<|>) :: Parser a -> Parser a -> Parser a
    (Parser a) <|> (Parser b) = Parser (
        \state -> case a state of
            Nothing -> b state
            x -> x
        )

instance Monad Parser where
    (>>=) :: Parser a -> (a -> Parser b) -> Parser b
    (>>=) aParser a2bFunc = Parser (
        \aState -> case parse aParser aState of
            Nothing -> Nothing
            Just (aResult, bState) -> parse (a2bFunc aResult) bState
        )

{-
    This is a wiki markup parser that separates out transcludes from
    other markup.
-}

type Page = [Chunk]

type ParamList = [(Maybe String,String)]
data Chunk =
    Markup
      { text      :: String
      , noinclude :: Bool
      }
    | Transclude
      { pageName :: String
      , params   :: ParamList
      }
    deriving (Show, Eq)

-- Runs the wiki markup parser on a string
parsePage :: String -> Page
parsePage s = runParser chunks s

-- Runs a parser on a string
runParser :: Parser a -> String -> a
runParser (Parser f) s =
    case f (ParserState s) of
        Nothing                  -> error "Parse failed"
        Just (x, ParserState "") -> x
        Just (x, ParserState s)  -> error $ "Incomplete parse: " ++ s

isAnyPrefixOf [] s = False
isAnyPrefixOf (p:xp) s = (p `isPrefixOf` s) || (xp `isAnyPrefixOf` s)

-- Check for a match without consuming any input.
match s = Parser $ \state ->
    if s `isAnyPrefixOf` (remaining state) then
        Just (s, state)
    else
        Nothing

-- Inverts a match parser
notp (Parser p) = Parser $ \state ->
    case p state of
        Nothing -> Just ([], state)
        otherwise -> Nothing

noMatch s = notp (match s)

-- Parses a single char
anyChar :: Parser Char
anyChar = Parser (\state ->
            case (remaining state) of
                ""       -> Nothing
                (c:cs)   -> Just (c, ParserState cs)
              )

-- Parses any char unless looking at one of the specified strings
anyExcept :: [String] -> Parser Char
anyExcept s = Parser $ \state ->
    if s `isAnyPrefixOf` (remaining state) then
        Nothing
    else
        parse anyChar state

-- Parses any fixed string
string :: String -> Parser String
string t = Parser (
    \state -> 
        case stripPrefix t (remaining state) of
            Just xs -> Just (t, ParserState xs)
            Nothing -> Nothing
    )

chunks :: Parser [Chunk]
chunks = many chunk

chunk :: Parser Chunk
chunk = transclude <|> markup

-- Parses consecutive open braces if the provided function returns
-- true. The function arg is the number of consecutive open braces.
numBraces :: (Int -> Bool) -> Parser String
numBraces func = Parser $ \state ->
    let rem = (remaining state)
        countBraces ('{':xs) cnt = countBraces xs (cnt + 1)
        countBraces _ cnt = cnt
        count = countBraces rem 0
    in
        if func count then
            Just (take count rem, ParserState $ drop count rem)
        else
            Nothing

-- Parses a transclude. Doesn't currently handle magic words.
transclude :: Parser Chunk
transclude = Transclude <$
    numBraces (== 2) <*>
    some (anyExcept [transEnd, "|"]) <*>
    many param <*
    string transEnd
    where
        param = (,) <$ string "|" <*> optional (id <* string "=") <*> id
        id = many (anyExcept [transEnd, "|", "="])
        transEnd = "}}"

-- Parses a chunk of non-transclude markup
markup :: Parser Chunk
markup = uncurry Markup <$> (incMarkup <|> noincMarkup)

noincludeBeg = "<noinclude>"
noincludeEnd = "</noinclude>"

incMarkup = (,False) <$> rawMarkup
noincMarkup = (,True) <$
    string noincludeBeg <*> rawMarkup <* string noincludeEnd

-- Parses raw markup that isn't parsed any further here
rawMarkup = concat <$> some ((++) <$>
                  numBraces (/= 2) <*
                  noMatch [noincludeBeg, noincludeEnd] <*>
                  ((:[]) <$> anyChar)
                            )
