{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.HelloTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.Hello (greet)

test_greet =
     do assertEqual "Hello, Alice." (greet "Alice")
