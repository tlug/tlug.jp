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
{-# LANGUAGE RecordWildCards #-}

module TLUG.MediaWiki
    ( Page, Chunk(..)
    , parsePage
    , parseFile
    , ProcPage(..)
    , runParser, char,
    ) where

import Control.Applicative;
import Data.List;
import Data.Maybe;
import Text.Read;

----------------------------------------------------------------------
--  Monadic parser framework

data ParserState = ParserState
    { remaining :: String
    }
newtype Parser a = Parser { parse :: (ParserState -> Maybe (a, ParserState)) }

instance Functor Parser where
    fmap :: (a -> b) -> Parser a -> Parser b
    fmap f (Parser parse) =
        Parser $ \state ->
            case parse state of
                Nothing -> Nothing
                Just (x, state') -> Just (f x, state')

instance Applicative Parser where
    pure :: a -> Parser a
    pure x = Parser $ \state -> Just (x, state)
    (<*>) :: Parser (a -> b) -> Parser a -> Parser b
    (Parser parse1) <*> parser2 =
        Parser $ \state -> case parse1 state of
            Nothing -> Nothing
            Just (f, state') -> parse (fmap f parser2) state'

instance Alternative Parser where
    empty :: Parser a
    empty = Parser $ return Nothing
    (<|>) :: Parser a -> Parser a -> Parser a
    (Parser parse1) <|> (Parser parse2) =
        Parser $ \state -> case parse1 state of
                               Nothing -> parse2 state
                               x -> x

instance Monad Parser where
    (>>=) :: Parser a -> (a -> Parser b) -> Parser b
    parser >>= k =
        Parser $ \state ->
            case (parse parser) state of
                Nothing -> Nothing
                Just (x, state') -> parse (k x) state'

-- | Run a given parser on a string
runParser :: Parser a -> String -> a
runParser (Parser f) s =
    case f (ParserState s) of
        Nothing                  -> error "Parse failed"
        Just (x, ParserState "") -> x
        Just (x, ParserState s)  -> error $ "Incomplete parse: " ++ s

----------------------------------------------------------------------
--  Parser for transcludes and other text from MediaWiki markup.

type ParamName  = Maybe String
type ParamValue = String
type Param     = (ParamName, ParamValue)
data Chunk
    = Markup String
    | Transclude { pageName :: String, params :: [Param] }
    | NoInclude Page
    | Parameter String
    | Redirect String
    deriving (Show, Eq)
type Page = [Chunk]

-- | Processed markup plus metadata (just redirect for now)
data ProcPage = ProcPage {
    body :: String,
    redirect :: Maybe String
    } deriving (Show, Eq)

-- | Process a top-level wiki markup file
parseFile :: String -> IO ProcPage
parseFile str = doTransclude [] True $ parsePage str

-- | Parse a wiki markup file
parseFile' :: [Param] -> Bool -> FilePath -> IO ProcPage
parseFile' par top file = parsePage <$> readFile file >>= doTransclude par top

-- | Replace Transclude chunks with their actual parse tree by reading
-- | and parsing the transclude file
doTransclude :: [Param] -> Bool -> Page -> IO ProcPage
doTransclude par True (NoInclude page:xs) = concatPP <$> (doTransclude par True page) <*> (doTransclude par True xs)
doTransclude par False (NoInclude _:xs) = doTransclude par False xs
doTransclude par top (Transclude{..}:xs) = concatPP <$> (parseFile' params False $ transFileName pageName) <*> (doTransclude par top xs)
doTransclude par top (Markup x:xs) = strPP x <$> doTransclude par top xs
doTransclude par top (Parameter x:xs) = strPP (replaceParam par x) <$> doTransclude par top xs
doTransclude par top (Redirect x:xs) = (\a -> a { redirect = Just x }) <$> doTransclude par top xs
doTransclude par top [] = return $ ProcPage "" Nothing

strPP :: String -> ProcPage -> ProcPage
strPP a b = b { body = a ++ body b }

concatPP :: ProcPage -> ProcPage -> ProcPage
concatPP a = strPP $ body a

replaceParam :: [Param] -> String -> String
replaceParam params name =
    let namepar = find (\(pn,pv) -> pn == Just name) params
        pospar = getParamIndex params (readMaybe name :: Maybe Int)
        par = if isJust namepar then namepar else pospar
    in
        case par of
            Just (_,np) -> np
            Nothing -> "<nowiki>{{{" ++ name ++ "}}}</nowiki>"
    where
        getParamIndex params pos = case pos of
            Nothing -> Nothing
            Just idx -> if (idx < 0) || (idx >= length params) then Nothing
                        else Just $ params !! idx

-- | Generate filename from a Transclude pageName
transFileName :: String -> FilePath
transFileName pageName =
    "wiki/" ++
    (if "Template:" `isPrefixOf` pageName then "" else "Template:") ++
    map (\a -> if a == ' ' then '_' else a) pageName

-- | Run the wiki markup parser on a string
parsePage :: String -> Page
parsePage s = runParser page s

-- | Parse a page
page :: Parser Page
page = many chunk

-- | Parse a single chunk
chunk :: Parser Chunk
chunk = markup <|> transclude <|> parameter <|> noInclude <|> redir

-- | Parse a chunk of non-transclude markup
markup :: Parser Chunk
markup = Markup <$>
    concat <$> some ((++) <$>
                        numBraces (\a -> (a /= 2) && (a /= 3)) <*
                        noMatch [noincludeBeg, noincludeEnd, redirTag] <*>
                        ((:[]) <$> char)
                    )

-- | Parse a transclude. Doesn't currently handle magic words.
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

parameter = Parameter <$
    numBraces (== 3) <*>
    some (anyExcept [paramEnd]) <*
    string paramEnd
    where paramEnd = "}}}"

noInclude :: Parser Chunk
noInclude = NoInclude <$ string noincludeBeg <*> page <* string noincludeEnd

noincludeBeg = "<noinclude>"
noincludeEnd = "</noinclude>"

redir = Redirect <$
    string (redirTag ++ " [[") <*
    many (string ":") <*>
    some (anyExcept [redirEnd]) <*
    string redirEnd
    where redirEnd = "]]"

redirTag = "#REDIRECT"

-- Parses consecutive open braces if the provided function returns
-- true. The function arg is the number of consecutive open braces.
numBraces :: (Int -> Bool) -> Parser String
numBraces f = Parser $ \state ->
    let count                       = countBraces rem 0
        rem                         = remaining state
        countBraces ('{':xs) cnt    = countBraces xs (cnt + 1)
        countBraces _ cnt           = cnt
    in
        if f count
            then Just (take count rem, ParserState $ drop count rem)
            else Nothing

isAnyPrefixOf [] s      = False
isAnyPrefixOf (p:xp) s  = (p `isPrefixOf` s) || (xp `isAnyPrefixOf` s)

-- Check for a match without consuming any input.
match s = Parser $ \state ->
    if s `isAnyPrefixOf` (remaining state)
        then Just (s, state)
        else Nothing

-- Inverts a match parser
notp (Parser p) = Parser $ \state ->
    case p state of
        Nothing -> Just ([], state)
        otherwise -> Nothing

noMatch s = notp (match s)

-- | Parse a single char
char :: Parser Char
char = Parser $ \state ->
    case (remaining state) of
        ""       -> Nothing
        (c:cs)   -> Just (c, ParserState cs)

-- Parses any char unless looking at one of the specified strings
anyExcept :: [String] -> Parser Char
anyExcept s = Parser $ \state ->
    if s `isAnyPrefixOf` (remaining state)
        then Nothing
        else parse char state

-- Parses any fixed string
string :: String -> Parser String
string t = Parser $ \state ->
    case stripPrefix t (remaining state) of
        Just xs -> Just (t, ParserState xs)
        Nothing -> Nothing
