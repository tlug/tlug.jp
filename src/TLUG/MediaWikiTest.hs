{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki

test_parse = do
     assertEqual [Markup "abc"] (parsePage "abc")
     assertEqual [Markup "hello"] (parsePage "hello")
