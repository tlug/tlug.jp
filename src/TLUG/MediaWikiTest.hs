{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki
import Data.Char
import Control.Applicative

test_runparser = do
    assertEqual 'x' (runParser char "x")

test_readNothing = do
    assertEqual 17 (runParser readNothingGiveInt "")

test_parserFmap = do
    assertEqual 'X' (runParser (fmap toUpper char) "x")

test_parserPure = do
    assertEqual 'a' (runParser (pure 'a') "")

test_parserApp = do
    assertEqual ('a','y') (runParser (pure (\a b -> (a,b)) <*> char <*> char) "ay")

test_parserApp2 = do
    assertEqual ('a','y') (runParser (liftA2 (\a b -> (a,b)) char char) "ay")

test_parserMonad = do
    assertEqual ('a','y') (runParser (do
                                             a <- char
                                             b <- char
                                             return (a,b)
                                     )
                           "ay")

{-
test_parsePage = do
    assertEqual [Markup "abc"] (parsePage "abc")

test_parse = do
     assertEqual [Markup "abc"] (parsePage "abc")
     assertEqual [ Markup "hello"
                 , Transclude "TranscludeName"
                     [("", "value1"), ("",""), ("name2", "value2")]
                 , Markup "goodbye"
                 ]
         (parsePage "hello{{TranscludeName|value1||name2=value2}}goodbye")
     assertEqual [Markup "hello", Transclude "hi" [("", "bye"), ("","")]]
         (parsePage "hello{{hi|bye|")
     assertEqual [Markup "hello"]
         (parsePage "hello{{")
-}
