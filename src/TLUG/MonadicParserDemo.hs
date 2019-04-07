{-  |
    An Explanation of Monadic Parsers in Haskell

    This demonstrates, with plenty of explanation, a simple Monadic parser
    built "from scratch."

    This is much simpler than the parser libraries such as Parsec[1][2].

    References:

    * [1]: https://hackage.haskell.org/package/parsec
    * [2]: https://en.wikibooks.org/wiki/Haskell/Practical_monads#Parsing_monads
-}

-- This runs the HTF (Haskell Test Framework) preprocessor to turn our
-- test_* functions below into tests that get run.
{-# OPTIONS_GHC -F -pgmF htfpp #-}

-- This allows us to use type signatures on the functions we define
-- in @instance@ declarations that supply the functions to make a
-- type a member of a class.
{-# LANGUAGE InstanceSigs #-}

module TLUG.MonadicParserDemo (htf_thisModulesTests) where
import Test.Framework


{-  |
    During the parse we need to maintain some state, which is the
    following. A state is contstructed when we start parsing and,
    after any relevant information is extracted from it, thrown away
    when parsing is complete.
-}
data ParserState = PState
    { input :: String       -- ^Text remaining to be parsed
    }


{-  |
    A "Parser of a" is a function that may be run during a parse and
    will give back a value of type "a". (Frequently it would parse
    this value out of the input stream.) These functions may be
    combined to produce new, more complex parsers, so they are called
    "combinators." They can be used only within a parse session. A
    parser that has no useful information to give back will generally
    give back '()' ("unit").

    Hidden inside a @Parser a@ is a function that takes a
    'ParserState' and returns a tuple of @(a, ParserState)@, that is,
    the value it wants to give back and the new, potentially updated
    state. (This function may be extracted with the 'unParser'
    function.) So internally the parser combinator has full access to
    use and change parser state, such as by reducing the remaining
    input (consuming input characters).

    This is probably the most difficult part of a monadic parser to
    understand.
-}
newtype Parser a = Parser { parse :: ParserState -> (a, ParserState) }

{-  |
    Run a 'Parser a' on the given input, returning the 'a' that it
    produces. To do this we need to build a new 'ParserState', feed
    that into the 'parse' function contained inside the 'Parser',
    and handle the result, which is the 'a' the parser gives back
    and the final state.

    In a more sophisticated parser framework we'd want to check the
    final state to see if there are errors, unconsumed input, or
    the like and handle that appropriately. But here we just throw
    away the final state and return the result.
-}
runParser :: String     -- ^Input to be parsed
          -> Parser a   -- ^Parser to run on the input
          -> a          -- ^Giving this result
runParser s (Parser parse) =
    let initialState = PState { input = s }
        (x, _finalState) = parse initialState
     in x

{-  |
    All instances of 'Monad' must be an instance of 'Functor'. An
    instance of Functor is an (extremely) generic "structure" of some
    sort, by which we mean just that a value of type @Functor a@ has
    some additional information beyond the value of type @a@ that's
    "contained in" the @Functor a@.

    For example, a 'Maybe a' contains the additional information that
    the @a@ is there or not: a @Maybe Int@ can be @Just 42@ or
    @Nothing@. A 'List a' contains additional information about
    length and order: a @List Int@ could be empty (@[]@), one Int
    (@[3]@) or three Ints in a specific order (@[3, 1, 2]@).

    In the case of 'Parser', the extra structure is the state of the
    parser, which is a relationship between parser combinators. For
    example, a parser that reads @3@ followed by @'b'@ from the input
    stream @"3b"@ could be built from a sequence of smaller parsers,
    one which reads @3@ from input @"3b"@ leaving input @"b"@
    remaining, and one which reads @'b'@ from the remaining @"b"@
    input, leaving @""@ remaining. This is an example of "structure"
    that involves what can be seen as control flow, in this case one
    thing happening before (rather than at the same time or after)
    another thing.

    Every instance of Functor has an 'fmap' function that that takes
    a function that can operate on the value(s) "contained in" the
    structure and produces a similar structure with that function
    applied to the "stuff inside" in some appropriate way for that
    particular instance.

    For example, @fmap f@ on a @Maybe Int@ will apply @f@ to the @n@
    of a @Just n@, producing a new @Just m@, but will do nothing at
    all to a @Nothing@, merely producing another @Nothing@. @fmap f@
    on a @List Int@ will apply @f@ to each value in the list @[n1,
    n2, n3]@ producing a list containing the results of those
    applications, @[m1, m2, m3]@. Note that in both cases the
    structure is preserved; @fmap@ on a 'Maybe' will always produce
    another 'Maybe', never a 'List', though the variation of 'Maybe'
    can change, e.g., @Maybe Int@ to @Maybe String@.

    'fmap' must satisfy the following properties:

    prop> fmap id  ==  id
    prop> fmap (f . g)  ==  fmap f . fmap g
-}
instance Functor Parser where
    {- |
        In our case, we convert a @Parser a@ to a @Parser b@ by
        running the parse function within the @Parser a@, putting the
        returned value through the @a -> b@, and preserving the
        (possibly updated) state returned by 'parse'.
    -}
    fmap :: (a -> b) -> Parser a -> Parser b
    fmap f (Parser parse) =
        Parser $                    -- 'fmap' gives back a new 'Parser b'
            \state ->               -- containing a function that takes a state
                let (x, state')     -- where we get back 'a' and new state
                      = parse state -- from running the 'Parser a'
                 in (f x, state')   -- and put value a through 'f'

test_functor =
     do -- Running parser 'give42' on any input always produces 42.
        assertEqual  42  (runParser "" give42)
        -- Running the version converted to give back a String produces "42".
        assertEqual "42" (runParser "" giveString)
    where
        -- | Parser that just gives the 'Int' 42, leaving the state unchanged.
        give42 :: Parser Int
        give42 = Parser $ \state -> (42, state)
        -- | Turn an 'Int' into its 'String' representation
        toString :: Int -> String
        toString x = show x
        -- | Use 'fmap' with 'toString' to convert the 'give42' parser
        --   into one that gives a String instead of an Int
        giveString = fmap toString give42
