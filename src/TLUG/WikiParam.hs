{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE RecordWildCards #-}

module TLUG.WikiParam
    ( replaceWikiParams
    ) where

import Control.Applicative;
import Data.List;
import Data.Maybe;
import Data.Char;
import Text.Read;
import TLUG.Parser;
import System.Directory;
import Debug.Trace;

type ParamDef = (Maybe String, String)

data Chunk
    = Markup String
    | Parameter String
    deriving (Show, Eq)
type Page = [Chunk]

-- | Top-level param replace function
replaceWikiParams :: [ParamDef] -> String -> String
replaceWikiParams pdef s = replaceParams pdef $ runParser page s

-- | Replace params in parsed page
replaceParams :: [ParamDef] -> Page -> String
replaceParams pdef (Parameter x:xs) = (replaceParam pdef x) ++ replaceParams pdef xs
replaceParams pdef (Markup x:xs) = x ++ replaceParams pdef xs
replaceParams pdef [] = ""

-- | Replace positional/named parameter references in a transcluded
-- | file (e.g. {{{param}}}) with the passed-in values.
replaceParam :: [ParamDef] -> String -> String
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
            Just pos -> if (pos < 1) || (pos > length params) then Nothing
                        else Just $ params !! (pos - 1)

-- | Parse a page
page :: Parser Page
page = many (markup <|> parameter)

-- | Parse a chunk of unprocessed markup
markup :: Parser Chunk
markup = Markup <$>
    some (noMatch ["{{{"] *> char)

-- | Parse a parameter
parameter = Parameter <$
    string "{{{" <*>
    some (anyExcept [paramEnd]) <*
    string paramEnd
    where paramEnd = "}}}"
