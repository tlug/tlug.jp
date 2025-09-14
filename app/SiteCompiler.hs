--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Control.Monad.Trans (liftIO)
import           Hakyll
import           Hakyll.Web.Html (withUrls)
import           Hakyll.Core.Rules.Internal
import           System.FilePath (joinPath, splitPath, replaceExtension)
import           Text.Pandoc (Pandoc, ReaderOptions, runPure, readMediaWiki)
import           Data.List (isPrefixOf)
import           Data.Text as DT (pack)
import           Data.Maybe;
import           Debug.Trace;
import           TLUG.MediaWiki
import           TLUG.WikiLink

--------------------------------------------------------------------------------

wikiCategoryRules :: Identifier -> Rules [String]
wikiCategoryRules = Rules . liftIO . (categories <$>) . (parseFile =<<) . readFile . toFilePath

createCategoryPages :: Tags -> Rules ()
createCategoryPages tags = do
  tagsRules tags $ \tag pattern -> do
    route $ idRoute -- setExtension "html"
    compile $ do
      posts <- {-recentFirst =<<-} loadAll pattern
      let context = constField "tag" tag `mappend`
                    listField "posts" defaultContext (return posts)
      makeItem ""
        >>= loadAndApplyTemplate "template/category.html" context
        >>= loadAndApplyTemplate "template/main.html" defaultContext
        >>= relativizeUrls

main :: IO ()
main = hakyll $ do
    match "template/*" $ do
        compile templateCompiler

    match "docroot/*.html" $ do
        route   dropInitialComponent
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "template/main.html" defaultContext

    -- All our "just serve these files" content.
    -- Much may be stuff we should build from nicer source, but don't.
    match "docroot/**" $ do
        route   dropInitialComponent
        compile copyFileCompiler

    match "wiki/*" $ do
        route   idRoute     -- No extension; netlify config serves as text/html
        compile mediawikiCompiler

    tags <- buildTagsWith wikiCategoryRules "wiki/*" (fromCapture "wiki/*")
    createCategoryPages tags

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
-- Custom code for our site

-- | Drop the given number of leading path components
dropInitialComponents :: Int -> Routes
dropInitialComponents n = customRoute $
    joinPath . drop n . splitPath . toFilePath

dropInitialComponent = dropInitialComponents 1

mediawikiCompiler :: Compiler (Item String)
mediawikiCompiler =
     do markup <- getResourceBody
        -- fpath <- getResourceFilePath; traceM fpath
        let parse = parseFile (itemBody markup)
        tcmarkup <- unsafeCompiler $ body <$> parse
        tcredir <- unsafeCompiler $ redirect <$> parse
        let tcitem = Item (itemIdentifier markup) tcmarkup
        if isJust tcredir
            then return $ Item (itemIdentifier markup) (makeRedir (fromJust tcredir) tcmarkup)
            else do
                pandoc <- read defaultHakyllReaderOptions tcitem
                let pdoc = writePandoc pandoc
                fixurl <- fixMediawikiUrls pdoc
                tmpl <- loadAndApplyTemplate "template/main.html" defaultContext fixurl
                return tmpl
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

-- FIXME: use the normal template but stick the redirect in the header
makeRedir :: String -> String -> String
makeRedir redir body =
    "<html><head><meta http-equiv=\"refresh\" content=\"0;URL='/wiki/" ++
    fixchars redir ++
    "'\" /></head><body><p>\n" ++
    body ++
    "</p></body></html>\n"
    where fixchars = map (\a -> if a == ' ' then '_' else a)

-- | Fix namespaced links generated by the mediawikiCompiler.
--
-- The mediawikiCompiler/pandoc produces links to other pages within the
-- site using relative URLs containing just the page name. This works fine
-- when the page has no namespace (@href="TLUG_Timeline"@) but breaks in
-- browsers when a namespace is present, as in @href="TLUG:Organization"@,
-- because that's interpreted as @tlug://Organization@ rather than
-- @http://www.tlug.jp/wiki/TLUG:Organization@.
--
-- MediaWiki deals with these by generating @/wiki/...@ URLs for all pages
-- within the wiki. Unfortunately, we can't tell at this stage whether
-- Pandoc was rendering an internal or external link, so we use a heuristic
-- of "see if the URL prefix is in the list of all namespaces we know
-- about" and add a @/wiki/@ in front of the URL if it is. If we find links
-- that this does not fix, we can update the list of known prefixes below.
--
fixMediawikiUrls :: Item String -> Compiler (Item String)
fixMediawikiUrls item = do
    return $ fmap (withUrls fixLink) item
    where
        fixLink url =
            if urlSchemeHack `isPrefixOf` url then
                drop (length urlSchemeHack) url
            else url

--------------------------------------------------------------------------------
-- Also sample blog site code

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext
