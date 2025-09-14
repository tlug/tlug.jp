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
import Debug.Trace;
import TLUG.Parser;
import TLUG.WikiLink;
import TLUG.WikiParam;

----------------------------------------------------------------------
--  Parser for transcludes and other text from MediaWiki markup.

type ParamName  = Maybe String
type ParamValue = String
type Param     = (ParamName, ParamValue)
data Chunk
    = Markup String
    | Transclude { pageName :: String, params :: [Param] }
    | NoInclude Page
    | Redirect String
    deriving (Show, Eq)
type Page = [Chunk]

-- | Processed markup plus metadata (just redirect for now)
data ProcPage = ProcPage {
    body :: String,
    redirect :: Maybe String,
    categories :: [String]
    } deriving (Show, Eq)

-- | Process a top-level wiki markup file
parseFile :: String -> IO ProcPage
parseFile str =
    (doTransclude [] True $ parsePage str) >>= fixlinks
    where fixlinks pp = (\(x, y) -> ProcPage x (redirect pp) y) <$> fixWikiLinks (body pp)

-- | Parse a wiki markup file
parseFile' :: [Param] -> Bool -> FilePath -> IO ProcPage
parseFile' par top file =
    if file == "" then return $ ProcPage "" Nothing []
    else parsePage <$> replaceWikiParams par <$> readFile ({-trace ("ReadFile: " ++ show file ++ ", " ++ show par)-} file) >>= doTransclude par top

-- | Replace Transclude chunks with their actual parse tree by reading
-- | and parsing the transclude file
doTransclude :: [Param] -> Bool -> Page -> IO ProcPage
doTransclude par True (NoInclude page:xs) = concatPP <$> (doTransclude par True page) <*> (doTransclude par True xs)
doTransclude par False (NoInclude _:xs) = doTransclude par False xs
doTransclude par top (Transclude{..}:xs) = concatPP <$> (parseFile' params False $ transFileName pageName) <*> (doTransclude par top xs)
doTransclude par top (Markup x:xs) = strPP x <$> doTransclude par top xs
doTransclude par top (Redirect x:xs) = (\a -> a { redirect = Just x }) <$> doTransclude par top xs
doTransclude par top [] = return $ ProcPage "" Nothing []

strPP :: String -> ProcPage -> ProcPage
strPP a b = b { body = a ++ body b }

concatPP :: ProcPage -> ProcPage -> ProcPage
concatPP a = strPP $ body a

-- | Generate filename from a Transclude pageName
transFileName :: String -> FilePath
transFileName pageName =
    -- not sure what this does, maybe looks up a caption?
    if "Image:" `isPrefixOf` pageName then ""
    else "wiki/" ++
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
chunk = markup <|> transclude <|> noInclude <|> redir

-- | Parse a chunk of non-transclude markup
markup :: Parser Chunk
markup = Markup <$>
    concat <$> some ((++) <$>
                        numBraces (/= 2) <*
                        noMatch [noincludeBeg, noincludeEnd, redirTag] <*>
                        ((:[]) <$> char)
                    )

-- | Parse a transclude. Doesn't currently handle magic words.
transclude :: Parser Chunk
transclude = Transclude <$
    numBraces (== 2) <*>
    some (anyExcept [transEnd, "|", "\n"]) <*
    many (anyExcept [transEnd, "|"]) <*>
    many param <*
    string transEnd
    where
        param = (,) <$ string "|" <*> optional (id <* string "=") <*> id
        id = (many space) *> many (anyExcept [transEnd, "|", "="])
        transEnd = "}}"

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
