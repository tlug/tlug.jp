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

module TLUG.MediaWiki
    ( Page, Chunk(..)
    , parsePage
    , runParser, anyChar,
    ) where

import Control.Applicative;
import Data.List;

type Page = [Chunk]

type ParamList = [(Maybe String,String)]
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
            Just (abFunc, bState) -> unParser (fmap abFunc aParser) bState
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
        \aState -> case unParser aParser aState of
            Nothing -> Nothing
            Just (aResult, bState) -> unParser (a2bFunc aResult) bState
        )

runParser :: Parser a -> String -> a
runParser (Parser f) s =
    case f (ParserState s) of
        Nothing                  -> error "Parse failed"
        Just (x, ParserState "") -> x
        Just (x, ParserState s)  -> error $ "Incomplete parse: " ++ s

match s = Parser $ \state ->
    if s `isPrefixOf` (remaining state) then
        Just (s, state)
    else
        Nothing

notp (Parser p) = Parser $ \state ->
    case p state of
        Nothing -> Just ([], state)
        otherwise -> Nothing

noMatch s = notp (match s)

anyChar :: Parser Char
anyChar = Parser (\state ->
            case (remaining state) of
                ""       -> Nothing
                (c:cs)   -> Just (c, ParserState cs)
              )

anyExcept s = Parser $ \state ->
    if anyPrefix s (remaining state) then
        Nothing
    else
        unParser anyChar state
    where
        anyPrefix [] s = False
        anyPrefix (p:xp) s = (p `isPrefixOf` s) || (anyPrefix xp s)

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

transclude :: Parser Chunk
transclude = (\a b -> Transclude a b) <$
    numBraces (== 2) <*>
    some (anyExcept [transEnd, "|"]) <*>
    many param <*
    string transEnd
    where
        param = (\a b -> (a,b)) <$ (string "|") <*> (optional (id <* string "=")) <*> id
        id = many (anyExcept [transEnd, "|", "="])
        transEnd = "}}"

markup :: Parser Chunk
markup = (\s -> Markup (concat s)) <$>
    some ((\a b -> concat [a, [b]]) <$>
          (numBraces (/= 2)) <*> anyChar)
