{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki
import Control.Applicative

test_parserApp = do
    assertEqual ('a','y') (runParser ((\a b -> (a,b)) <$> char <*> char) "ay")
    assertEqual ('a','y') (runParser (liftA2 (\a b -> (a,b)) char char) "ay")

test_parserMonad = do
    assertEqual ('a','y') (runParser (do
                                             a <- char
                                             b <- char
                                             return (a,b)
                                     )
                           "ay")

test_parse = do
    assertEqual [] (parsePage "")
    assertEqual [Markup "abc"] (parsePage "abc")
{-
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
