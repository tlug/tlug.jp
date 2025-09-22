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
    | Image { ref :: String, args :: String }
    | Category { ref :: String, args :: String }
    deriving (Show, Eq)
type Page = [Chunk]

-- | Top-level link fixup function, also returns a list of category tags found
fixWikiLinks :: String -> IO (String, [String])
fixWikiLinks s = do
    files <- listDirectory "wiki"
    images <- listDirectory "docroot/images"
    fixLinks files images $ runParser page s

fixLinks :: [FilePath] -> [FilePath] -> Page -> IO (String, [String])
fixLinks files images (x:xs) = do
    str <- case x of
               WikiLink ref anc text -> cleanupWikiLink files ref anc text
               Anchor s -> return s
               Image ref arg -> cleanupImageLink images ref arg
               Category cat arg -> return (addCategory cat arg)
               Markup s -> return s
    let cat = case x of
               Category cat arg -> [getCategory cat arg]
               otherwise -> []
    (remstr, remcat) <- fixLinks files images xs
    return $ (str ++ remstr, remcat ++ cat)
fixLinks files images [] = return ("", [])

-- | Clean up a normal wiki link
cleanupWikiLink :: [FilePath] -> String -> String -> String -> IO String
cleanupWikiLink files ref anc text = do
    let file = getWikiFile files (replChars $ delEndSpace $ ref)
    return $ if file == ""
        then {-trace ("BADLINK: "++ ref)-} "<font color=#CC2200>" ++
        (if text == "" then ref else text)
        ++ "</font>"
        else wikiLink2Link (file ++ anc) ref text
    where
        delEndSpace = dropWhileEnd isSpace

-- | Clean up an image link
cleanupImageLink :: [FilePath] -> String -> String -> IO String
cleanupImageLink files ref arg = do
    let file = getWikiFile files (replChars $ delEndSpace $ ref)
    return $ if file == ""
        then {-trace ("BADIMG: "++ ref)-} "<font color=#CC2200>" ++ ref ++ "</font>"
        else "[[Image:/images/" ++ file ++ arg ++ "]]"
    where
        delEndSpace = dropWhileEnd isSpace

-- | Clean up an category link
addCategory :: String -> String -> String
addCategory ref arg = do
    let catfile = "Category:" ++ ref
    wikiLink2Link catfile catfile ""

-- | Return category name
getCategory :: String -> String -> String
getCategory ref arg = "Category:" ++ ref

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
page = many (markup <|> wikilink <|> anchor <|> image <|> category)

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
    noMatch ["#", "Image:", "Category:"] <*
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
    some (anyExcept ["]", "|"]) <*>
    args <*
    string "]]"
    where
        argstr s = if isJust s then fromJust s else ""
        args = argstr <$>
            optional ((++) <$> string "|" <*> (some $ anyExcept ["]"]))

-- | Parse a category tag
category :: Parser Chunk
category = Category <$
    string (wikilinkBeg ++ "Category:") <*>
    some (anyExcept ["]", "|"]) <*>
    args <*
    string "]]"
    where
        argstr s = if isJust s then fromJust s else ""
        args = argstr <$>
            optional ((++) <$> string "|" *> (some $ anyExcept ["]"]))
