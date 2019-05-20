{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki
import Control.Applicative

test_parserApp = do
    assertEqual
        ('a','y')
        $ runParser ((\a b -> (a,b)) <$> anyChar <*> anyChar) "ay"
    assertEqual
        ('a','y')
        $ runParser (liftA2 (\a b -> (a,b)) anyChar anyChar) "ay"

test_parserMonad =
    let parser = do a <- anyChar
                    b <- anyChar
                    return (a,b)
    in assertEqual ('a','y') $ runParser parser "ay"

test_parse = do
    assertEqual
        []
        $ parsePage ""
    assertEqual
        [Markup "abc" False]
        $ parsePage "abc"
    assertEqual
        [Transclude "trans:a b" []]
        $ parsePage "{{trans:a b}}"
    assertEqual
        [Markup "** " False, Transclude "w:ja" [(Nothing,"利用者:name")]]
        $ parsePage "** {{w:ja|利用者:name}}"
    assertEqual
        [Markup "inc" False, Markup "noinc" True]
        $ parsePage "inc<noinclude>noinc</noinclude>"
    assertEqual
        [ Markup "begin" False
        , Transclude "trans"
            [ (Nothing,"value1"), (Nothing,""), (Just "name2","value2") ]
        , Transclude "t2" []
        , Markup "end" True
        ]
        $ parsePage  $ "begin{{trans|value1||name2=value2}}"
                    ++ "{{t2}}<noinclude>end</noinclude>"
    assertEqual
        [Markup "{{{}}}{{{{}}}}{}" False]
        $ parsePage "{{{}}}{{{{}}}}{}"

{- How do we test errors?
    assertEqual [Markup "hello", Transclude "hi" [("", "bye"), ("","")]]
        (parsePage "hello{{hi|bye|")
    assertEqual [Markup "hello"]
        (parsePage "hello{{")
-}
