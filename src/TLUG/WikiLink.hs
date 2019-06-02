{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE RecordWildCards #-}

module TLUG.WikiLink
    ( fixWikiLinks
    , urlSchemeHack
    ) where

import Control.Applicative;
import Data.List;
import Data.Maybe;
import Data.Char;
import Text.Read;
import TLUG.Parser;
import System.Directory;
import Debug.Trace;

data Chunk
    = Markup String
    | WikiLink { ref :: String, anc :: String, text :: String }
    | Anchor String
    | Image String
    deriving (Show, Eq)
type Page = [Chunk]

-- | Top-level link fixup function
fixWikiLinks :: String -> IO String
fixWikiLinks s = do
    files <- listDirectory "wiki"
    fixLinks files $ runParser page s

fixLinks :: [FilePath] -> Page -> IO String
fixLinks files (x:xs) = do
    str <- case x of
               WikiLink ref anc text -> cleanupWikiLink files ref anc text
               Anchor s -> return s
               Image s -> return $ "[[Image:/images/" ++ s ++ "]]"
               Markup s -> return s
    rem <- fixLinks files xs
    return $ str ++ rem
fixLinks files [] = return ""

-- | Clean up a normal wiki link
cleanupWikiLink :: [FilePath] -> String -> String -> String -> IO String
cleanupWikiLink files ref anc text = do
    let file = getWikiFile files (replChars $ delEndSpace $ ref)
    return $ if file == ""
        then {-trace ("BADLINK: "++ ref)-} ref
        else wikiLink2Link (file ++ anc) ref text
    where
        delEndSpace = dropWhileEnd isSpace

-- | Convert special chars into their filename encoding
replChars :: String -> String
replChars (x:xs) = (replChar x) ++ (replChars xs)
replChars "" = ""

replChar :: Char -> String
replChar c = case c of
    ' ' -> "_"
    '(' -> "%28"
    ')' -> "%29"
    '"' -> "%22"
    '“' -> "%22"
    '”' -> "%22"
    otherwise -> [c]

-- | Get filename based on link
getWikiFile :: [FilePath] -> String -> String
getWikiFile (x:xs) ref =
    if (map toLower x) == (map toLower ref) then x
    else getWikiFile xs ref
getWikiFile [] ref = ""

-- | Encode internal wiki as a regular link for pandoc
wikiLink2Link :: String -> String -> String -> String
wikiLink2Link file ref text =
    "[" ++
    ((urlSchemeHack ++ "./") ++ (repPct file)) ++
    " " ++
    (if text == "" then ref else text) ++
    "]"
    where -- Pandoc converts % codes back into the original chars
        repPct (x:xs) = (if x == '%' then "%25" else [x]) ++ (repPct xs)
        repPct "" = ""

-- This is a hack to pass wiki links through pandoc so they can be
-- generated as relative links, which don't work inside an external
-- ([...]) link because there's a URL scheme whitelist.
urlSchemeHack = "adiumxtra:"

-- | Parse a page
page :: Parser Page
page = many (markup <|> wikilink <|> anchor <|> image)

-- | Parse a chunk of unprocessed markup
markup :: Parser Chunk
markup = Markup <$>
    concat <$> some ((++) <$>
                        noMatch [wikilinkBeg] <*>
                        ((:[]) <$> char)
                    )

-- | Parse a regular wiki link
wikilink :: Parser Chunk
wikilink = WikiLink <$
    string wikilinkBeg <*
    noMatch ["#", "Image:"] <*
    optional (string ":") <*>
    some (anyExcept ["]", "|", "#"]) <*>
    embanchor <*
    optional (string "|") <*
    many (string " ") <*>
    many (anyExcept ["]"]) <*
    string "]]"
    where
        ancstr s = if isJust s then "#" ++ fromJust s else ""
        embanchor = ancstr <$>
            optional (string "#" *> (some $ anyExcept ["]", "|"]))

wikilinkBeg = "[["

-- | Parse an anchor-only link
anchor :: Parser Chunk
anchor = Anchor <$> string (wikilinkBeg ++ "#")

-- | Parse an image reference
image :: Parser Chunk
image = Image <$
    string (wikilinkBeg ++ "Image:") <*>
    some (anyExcept ["]"]) <*
    string "]]"
