{-
    An Explanation of Monadic Parsers in Haskell

    Parsec[3][4]

    References:

    * [3]: https://hackage.haskell.org/package/parsec
    * [4]: https://en.wikibooks.org/wiki/Haskell/Practical_monads#Parsing_monads

-}
{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MonadicParserTest (htf_thisModulesTests) where
import Test.Framework

test_2 = assertEqual 0 2

test_3 = assertEqual 0 3
