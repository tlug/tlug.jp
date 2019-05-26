{-# OPTIONS_GHC -F -pgmF htfpp #-}

module TLUG.MediaWikiTest (htf_thisModulesTests) where

import Test.Framework
import TLUG.MediaWiki
import Control.Applicative

test_parserApp = do
    assertEqual
        ('a','y')
        $ runParser ((\a b -> (a,b)) <$> char <*> char) "ay"
    assertEqual
        ('a','y')
        $ runParser (liftA2 (\a b -> (a,b)) char char) "ay"

test_parserMonad =
    let parser = do a <- char
                    b <- char
                    return (a,b)
    in assertEqual ('a','y') $ runParser parser "ay"

test_parse = do
    assertEqual
        []
        $ parsePage ""
    assertEqual
        [Markup "abc"]
        $ parsePage "abc"
    assertEqual
        [Transclude "trans:a b" []]
        $ parsePage "{{trans:a b}}"
    assertEqual
        [Markup "** ", Transclude "w:ja" [(Nothing,"利用者:name")]]
        $ parsePage "** {{w:ja|利用者:name}}"
    assertEqual
       [Markup "inc", NoInclude [Markup "noinc", NoInclude [Markup "doublenoinc"]]]
        $ parsePage "inc<noinclude>noinc<noinclude>doublenoinc</noinclude></noinclude>"
    assertEqual
        [ Markup "begin"
        , Transclude "trans"
            [ (Nothing,"value1"), (Nothing,""), (Just "name2","value2") ]
        , NoInclude
          [ Transclude "t2" []
          , Markup "end"
          ]
        ]
        $ parsePage  $ "begin{{trans|value1||name2=value2}}"
                    ++ "<noinclude>{{t2}}end</noinclude>"
    assertEqual
        [Markup "{{{}}}{{{{}}}}{}"]
        $ parsePage "{{{}}}{{{{}}}}{}"


test_file = do
    output <- readFile "wiki/Meetings:2019:02" >>= parseFile
    assertEqual "\
\== Introduction ==\n\
\All Linux lovers, and supporters of open source code and free software, in the Kanto area (or anywhere else) are invited to attend the next Tokyo Linux Users Group meeting. <b>Membership is open to anyone</b>. There are currently <b>no membership dues</b> or entrance fees.\n\
\\n\
\TLUG meetings are traditionally small and unstructured (VERY CASUAL). Most of the benefit of the meeting comes from chatting with other Linux users and having informal discussions.\n\
\\n\
\As a general rule, the Technical Meetings are held on the 2nd Saturday of odd-numbered months and the Nomikai Meetings are usually held on the 2nd Friday of even-numbered months. There are, of course, exceptions to this rule, so it is best to keep an eye on the mailing list, or check back here for date/venue changes as the date approaches. \n\
\\n\
\== Nomikai ==\n\
\==== Date ====\n\
\February 8, 2019 (Friday)\n\
\\n\
\==== Time ====\n\
\19:30 - 21:30\n\
\\n\
\==== Event ====\n\
\Eat and drink (primarily a social activity)\n\
\\n\
\==== Location ====\n\
\'''Sudacho Shokudo'''<br />\n\
\Akihabara UDX 3F, 4-14-1, Sotokanda, Chiyoda-ku, Tokyo, 101-0021<br />\n\
\[ [https://gurunavi.com/en/g095630/rst/ Info] ]\n\
\[ [https://r.gnavi.co.jp/g095630/ Info(ja)] ] \n\
\[ [https://goo.gl/maps/bcFW1mDpoZ82 map] ]\n\
\\n\
\\n\
\To help us make sure that there will be room for everyone\n\
\to seat, please register your attendance here:\n\
\\n\
\https://tlug.doorkeeper.jp/events/86787\n\
\\n\
\==== Cost ====\n\
\\n\
\Around 4,000yen\n\
\\n\
\=== Details ===\n\
\This event is open to all Linux users and friends, and is to promote casual Linux (and non-Linux) related discussions over a few cold ones. Even if you're not a Linux user or a LUG member, but want to hang out with Linux people, please come.\n\
\         \n\
\=== Contact Info ===\n\
\For directions or information before the meeting, call:\n\
\* Justin: 050-5806-9898\n\
\\n\
\[[Category:Meetings|{{{year}}}:{{{month}}}]]\n\
\[[Category:Meetings:{{{year}}}|{{{month}}}]]\n\
\\n\
\\n"
        output

{- How do we test errors?
    assertEqual
        [Markup "hello", Transclude "hi" [(Nothing,"bye"), (Nothing,"")]]
        $ parsePage "hello{{hi|bye|"
    assertEqual
        [Markup "hello"]
        $ parsePage "hello{{"
-}
