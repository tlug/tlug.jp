{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki

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
