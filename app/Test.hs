{-# OPTIONS_GHC -F -pgmF htfpp #-}

module Main where

import Test.Framework
import {-@ HTF_TESTS @-} TLUG.HelloTest
import {-@ HTF_TESTS @-} TLUG.MediaWikiTest

main :: IO ()
main = htfMain htf_importedTests
