--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           System.FilePath (joinPath, splitPath, replaceExtension)
import           Text.Pandoc (Pandoc, ReaderOptions, runPure, readMediaWiki)
import           Data.Text as DT (pack)

--------------------------------------------------------------------------------

mediawikiCompiler :: Compiler (Item String)
mediawikiCompiler =
     do markup <- getResourceBody
        pandoc <- read defaultHakyllReaderOptions markup
        return $ writePandoc pandoc
    where
        ropt = defaultHakyllReaderOptions
        -- This is a copy of Hakyll.Web.Pandoc.readPandocWith the first
        -- argument to `traverse` replaced with `readMediaWiki ropt`
        -- because the original function is hardcoded to select the Pandoc
        -- read function based on the source file extension, which our
        -- source files do not have.
        read :: ReaderOptions -> Item String -> Compiler (Item Pandoc)
        read ropt item =
            case runPure $ traverse (readMediaWiki ropt) (fmap DT.pack item) of
                 Left err    -> fail $ "MediaWiki parse failed: " ++ show err
                 Right item' -> return item'

main :: IO ()
main = hakyll $ do

    -- All our "just serve these files" content.
    -- Much may be stuff we should build from nicer source, but don't.
    match "docroot/**" $ do
        route   dropInitialComponent
        compile copyFileCompiler

    match "wiki/*" $ do
        route   idRoute     -- No extension; netlify config serves as text/html
        compile $ do
            -- pandocCompiler
            mediawikiCompiler

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

-- Drop the given number of leading path components
dropInitialComponents :: Int -> Routes
dropInitialComponents n = customRoute $
    joinPath . drop n . splitPath . toFilePath

dropInitialComponent = dropInitialComponents 1

--------------------------------------------------------------------------------
-- Also sample blog site code

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext
