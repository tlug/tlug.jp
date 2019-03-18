--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll


--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do

    match "index.html" $ do
        route idRoute
        compile copyFileCompiler

    match "index.ja.html" $ do
        route idRoute
        compile copyFileCompiler

    -- This is the path used for CSS, images, etc. on the old site;
    -- we should probably tidy this up.
    match "tlug_template/*" $ do
        route   idRoute
        compile copyFileCompiler

    -- The rest of this is the sample code for a blog site from the
    -- initial project template. We're keeping this here as an example
    -- until we've extracted everything we need from it.

    match "example/images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "example/css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["example/about.rst", "example/contact.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate
                "example/templates/default.html" defaultContext
            >>= relativizeUrls

    match "example/posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "example/templates/post.html"    postCtx
            >>= loadAndApplyTemplate "example/templates/default.html" postCtx
            >>= relativizeUrls

    create ["example/archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "example/posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext
            makeItem ""
                >>= loadAndApplyTemplate
                    "example/templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate
                    "example/templates/default.html" archiveCtx
                >>= relativizeUrls

    match "example/index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "example/posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultContext
            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate
                    "example/templates/default.html" indexCtx
                >>= relativizeUrls

    match "example/templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

