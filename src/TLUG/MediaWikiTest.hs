{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki

test_parse = do
     assertEqual [Markup "abc"] (parsePage "abc")
     assertEqual [Markup "hello", Transclude "ThisIsATransclude" [], Markup "goodbye"]
         (parsePage "hello{{ThisIsATransclude|param1|param2=hi}}goodbye")
     assertEqual [Markup "hello", Transclude "hi" []]
         (parsePage "hello{{hi")
