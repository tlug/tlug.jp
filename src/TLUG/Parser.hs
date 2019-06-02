{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE RecordWildCards #-}

module TLUG.Parser
    ( Parser(..)
    , ParserState(..)
    , runParser
    , char
    , string
    , anyExcept
    , noMatch
    ) where

import Control.Applicative;
import Data.List;
import Data.Maybe;
import Data.Char;
import Text.Read;

----------------------------------------------------------------------
-- Parser framework

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
        Nothing                  -> error $ "Parse failed: " ++ s
        Just (x, ParserState "") -> x
        Just (x, ParserState s)  -> error $ "Incomplete parse: " ++ s

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
