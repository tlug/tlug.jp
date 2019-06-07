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

-- This allows us to use type signatures on the functions we define in
-- @instance@ declarations. The instance declarations make a type a a
-- type a member of a class by supplying the functions must be
-- available for every member of that class.
{-# LANGUAGE InstanceSigs #-}

module TLUG.MonadicParserDemo (htf_thisModulesTests) where
import Test.Framework


{-  |
    During a parse we need to maintain some state, which we wrap up
    in a value of the following 'ParserState' type. We construct the
    initial version of this state when we start parsing a document
    and, when done, extract any relevant information from it before we
    throw it away.

    The type system will make sure that values of this state exist and
    are handled only during a specific parse run; they cannot leak out
    to the rest of the program.
-}
data ParserState = PState
    { input :: String       -- ^Text remaining to be parsed
    }


{-  |
    A "Parser of a" is a function that may be run during a parse and
    will produce a value of type "a". (Usually it would parse this
    value out of the input stream.) These functions may be combined to
    produce new, more complex parsers, so they are called "combinators."
    The combinators can be used only within a parse run, and this is
    enforced by the type system. A parser that produces "no value"
    (i.e., is used for its side-effects only) will by convention
    produce '()', the sole inhabitant of type '()' (both pronounced
    "Unit").

    Stored inside a @Parser a@ is a function that takes a 'ParserState'
    and produces a tuple @(a, ParserState)@, this being the value it
    wants to produce and the new (usually updated) state. (This
    function may be extracted with the 'parse' function automatically
    defined by our label on the field below.) So internally the parser
    combinator has full access to use and change parser state, such as
    by reducing the remaining input (consuming input characters), but
    this isn't visible from the outside.

    The whole point behind wrapping functions up in this data
    structure is to separate the "pure" parts of a parsing function
    (such as converting a string to a number) from the other details,
    such as the current parser state and selection and order of parser
    functions, which we call the "structure" of a Parser. (This is
    probably the most difficult part of a monadic parser to
    understand.) We will later see how we split up the functions that
    deal with parsing and the other functions that deal with these
    structural issues.
-}
newtype Parser a = Parser { parse :: ParserState -> (a, ParserState) }

{-  |
    This starts and completes a parse run by running a (top-level)
    'Parser a' on the given input, producing the value of type 'a'
    (typically the fully parsed AST) that the 'Parser a' produced.

    To do this we need to build a new 'ParserState', feed that into
    the 'parse' function contained inside the 'Parser', and handle the
    result, which is the value of type 'a' produced by the 'Parser a'
    and the final state.

    In a more sophisticated parser framework we'd want to check the
    final state to see if there are errors, unconsumed input, or the
    like and handle that appropriately. But here we just throw away
    the final state and produce the result.
-}
runParser :: String     -- ^Input to be parsed
          -> Parser a   -- ^Parser to run on the input
          -> a          -- ^Giving this result
runParser s (Parser parse) =
    let initialState = PState { input = s }
        (x, _finalState) = parse initialState
     in x

{-  |
    Now comes the first "structural" part. We make our 'Parser' data
    type an instance of 'Functor'. An instance of Functor is an
    (extremely) generic "structure" of some sort, by which we mean
    just that a value of type @Functor a@ has some additional
    information beyond the "pure" value of type @a@ that's "contained
    in" the @Functor a@.

    Some examples:
    1. The optional type 'Maybe a' contains additional information
       about whether a pure value of type @a@ is present or not: a
       @Maybe Int@ can be @Just 42@ (present, and 42) or @Nothing@
       (absent).
    2. The list type '[a]' contains additional information about the
       number of values of type @a@ present (0, 1, 2, etc.) and the
       order of these values in relation to each other. A list of
       'Int' @[Int]@ could be empty (@[]@), one Int (@[3]@) or three
       Ints in a specific order (@[3, 1, 2]@).

    Every instance of Functor has an 'fmap' function. `fmap` takes a
    function that can operate on the pure value(s) "contained in" the
    structure of the functorial value and produces an identical
    structure where that function has been applied to the pure values
    "inside" in some appropriate way for that particular instance.

    Examples, where @f x = x + 1@:
    1. @fmap f@ on a @Maybe Int@ has two choices. If the value is
       @Just 3@, it can extract the @3@ and apply @f@ to it,
       afterwards re-enclosing the result @4@ into the structure as
       @Just 4@. If the value is @Nothing@, however, the special
       behaviour of 'Functor Maybe' is triggered, @f@ is not applied
       to anything, and @Nothing@ is the result produced.
    2. The behaviour of @fmap f@ on @[Int]@; is different because it
       must be particular to the list structure: it applies the
       function multiple times, once to each pure value inside the
       structure. Thus @fmap f [2,3]@ results in @[f 2,f 3]@.

    An important characteristic of 'fmap' is that, because the pure
    function passed to 'fmap' knows nothing about the structure,
    'fmap' can never change the structure. 'fmap' on a 'Maybe' may
    never change a @Just x@ to a @Nothing@ or vice versa becuase the
    pure function knows nothing about the presence or absence of an
    optional value; that's part of the structure that 'fmap' never
    changes. Similarly, 'fmap' on a list may never change the length
    or order of a list because the pure function doesn't know anything
    about lengths or ordering; the length and order of a list is part
    of the list's structure, not connected to the pure values in the
    list.

    This is expressed in the following laws of 'fmap'. (If you are
    mathematically inclined you can prove that any 'fmap' function
    that follows these laws can never change the structure.)

    prop> fmap id  ==  id
    prop> fmap (f . g)  ==  fmap f . fmap g

    Unlike more sophisticated languages, Haskell cannot check these
    laws; we rely on the programmer to make sure that he writes a
    function that will never break them.

    In our case of 'Parser', the extra structure we add is the
    'ParserState' that we always send in to a parse function and
    retrieve (in possibly modified form) as part of the output. We
    provide an 'fmap' function that accepts a pure function (which
    knows nothing about this extra structure) and applies it to the
    result of a Parser, giving us a new Parser incorporating this pure
    function. Thus the type signature:

        @fmap :: (a -> b) -> Parser a -> Parser b@

    @(a -> b)@ is the pure function, @Parser a@ is the Parser
    producing the result to which we will apply this pure function,
    and @Parser b@ is a new parser incorporating this pure function.
    See the tests below for examples of how this works.
-}
instance Functor Parser where
    fmap :: (a -> b) -> Parser a -> Parser b
    fmap f (Parser parse) =
        Parser $                    -- 'fmap' produces a new 'Parser b'
            \state ->               -- containing a function that takes a state
                let (x, state')     -- where we get back an 'a' and new state
                      = parse state -- from running the 'Parser a'
                 in (f x, state')   -- and put the pure value through 'f'

test_functor =
     do -- Running Parser 'theAnswer' on any input always produces Int 42.
        assertEqual  42  (runParser "" theAnswer)
        -- Running the Parser converted to produce a String produces "42".
        assertEqual "42" (runParser "" theAnswerAsString)
    where
        -- | Parser that just gives the 'Int' 42, leaving the state unchanged.
        theAnswer :: Parser Int
        theAnswer = Parser $ \state -> (42, state)
        -- | Turn an 'Int' into its 'String' representation
        toString :: Int -> String
        toString x = show x
        -- | Use 'fmap' with 'toString' to convert the 'give42' parser
        --   into one that produces a String instead of an Int
        theAnswerAsString = fmap toString theAnswer

{-  |
    The next step towards a Monad is the 'Applicative' typeclass. This
    is actually a special kind of Functor (as evidenced by the fact
    that anything that is an 'Applicative' must also be a 'Functor')
    whose full name is "applicative functor." (Or, if you want to
    impress your friends, you can use the more math-y name, "strong lax
    monoidal functor.")

    We won't speak too much here about how Applicative is used in
    programs (though some parsers work in just Applicative alone,
    without being Monads), but this is where the structure starts
    covering not just a single functorial value but the relationships
    between applicative functorial values.

    To be applicative we must offer two additional functions that
    bridge the world between pure values and functions and our
    structure: 'pure' and the binary operator '<*>'. We'll declare the
    instance first with refrences to the actual functions and then
    discuss each function in turn.
-}

instance Applicative Parser where

    pure :: a -> Parser a
    pure = parserPure

    (<*>) :: Parser (a -> b) -> Parser a -> Parser b
    (<*>) = parserApply

{-  |
    'pure' solves the problem of how we create a new structure
    "containing" a pure value or function. (This is generally called
    "lifting" into the structure, though the various functions that do
    this go by many names.)

    Examples:
    1. @pure 3@ into @Maybe Int@ produces @Just 3@.
    2. @pure 3@ into a list of Int, @[Int]@, produces @[3]@.

    This is much more restrictive than what we can do with the actual
    constructors for structure types: we cannot use 'pure' to create a
    'Nothing', an empty list, or a list of more than one value since
    all of these involve structure and less or more than one pure
    value. However, for our particular purposes here, where we just
    want to get to Monad anyway, we don't need to worry about the
    reasons for this right now.

    For the case of our Parser, 'pure' is quite simple. The pure value
    is what the parser produces and the structure is a function that
    takes and produces a state, so we simply create a new Parser
    containing a function that takes a state and produces our pure
    value along with that same state. Thus, as shown by
    'test_applicative_pure', using 'runParser' on that Parser should
    do nothing with the state and produce what was put in with 'pure'.
-}
parserPure :: a -> Parser a
parserPure x = Parser $ \state -> (x, state)

test_applicative_pure =
     do --  What we put in with pure, we get out
        assertEqual 13 (runParser "" (pure 13))

{-  |
    Since we're about to become a Monad, rather than remain
    Applicative, we don't need to worry much about the '<*>' ("apply")
    function; this is just Monad's 'ap' function. However, we
    implement it here, rather than re-using `ap` as provided by Monad
    because this serves a useful pedagogical purpose.

    The idea here is that apply lets you execute functions that have
    been lifted into the structure (e.g. via 'pure') to arguments also
    in the structure. Let's say we have a pure function @double x = x
    * 2@ and a pure value @3@. In the pure world, @double 3@ would
    produce @6@. But both the function and its argument can be lifted
    up into the Applicative functor and be run there via @pure double
    <*> pure 3@, giving back the same thing as @pure (double 3)@:
    i.e., all the structure in the Applicative functor is preserved
    and dealt with properly by 'pure' and '<*>'.

    So while here we don't care why we need '<*>', how it works is
    worth understanding.

    Our Parser's structure around pure values so far has been "a
    function that takes a state and produces the new state plus the
    pure value." But we actually want more structure than that (this
    is why we're not just a Functor): we want also to /chain/ the
    state through sequential applications of the functions in the
    Parsers. (A change in the state would be no good to us if that
    change disappeared before the next step in the parse!) For
    example, if a parser combinator consumes the first character of
    the string to be parsed, the next combinator should see only the
    remainder of the string, without that first character.

    The '<*>' operator is the first time so far we've seen explicit
    sequencing of two Parsers, and our implementation of '<*>'
    reflects that. Our implementation of '<*>' produces a new Parser
    containing a parse function that, in the usual way, accepts a
    state and produces a new state plus a result value. The sequence
    of operations is:
    1. Via pattern matching, extract the two parse functions,
       @parse_f@ and @parse_x@ from the two Parsers we've been given.
    2. Apply the first parse function, @parse_f@, to our input @state@
       to produce a (possibly modified) @state'@ ("state-prime", the
       usual terminology for a modified copy in Haskell) and the pure
       result value of @parse_f@, which is the function to apply.
    3. Apply the second parse function, @parse_x@ to the new @state'@
       to produce the next state, @state''@ and the pure value to
       which to apply the function we got above.
    4. Apply the pure function @f@ from the first Parser to the pure
       value @x@ from the second Parser to produce a new pure result
       value.
    5. Produce that new pure result value and the final state after
       modification (if any) by the first and second Parsers.

    In other words, we have two separate streams of operations here:
    passing the state through each Parser in turn to update it, and
    applying the pure function "contained" in the first parser to the
    pure value "contained" in the second parser. At the end, we wrap
    up the results of these two streams together for further
    processing.

    'test_applicative_apply' below demonstrates two uses of this. The
    first applies a function of a single argument ("double") to a
    single value. The second, in the typical Haskell way, partially
    applies a function taking two arguments ("multiply") to the first
    value to produce a function taking a single argument which,
    applied to the second values, produces the result. (Technically,
    in Haskell a function that takes two values is actually a function
    that takes one value and produces another function that takes one
    value. This is called "partial application.")
-}
parserApply :: Parser (a -> b) -> Parser a -> Parser b
(Parser parse_f) `parserApply` (Parser parse_x) =
    Parser $ \state ->
        let (f, state')  = parse_f state
            (x, state'') = parse_x state'
         in (f x, state'')

test_applicative_apply =
     do --  Lift function that doubles and apply to 3.
        assertEqual  6 (runParser "" $ pure (*2) <*> pure 3)
        --  Lift multiply and partially apply to 3, then apply to 5.
        assertEqual 15 (runParser "" $ pure (*) <*> pure 3 <*> pure 5)

{- You may have noticed that extracting the pure value from a Functor,
   applying a pure function to it, and putting the pure result back
   into a Functor is something we've already written before: 'fmap'.
   If so, good for you! We could actually re-use this code in our
   definition above:

parserApply :: Parser (a -> b) -> Parser a -> Parser b
(Parser parse_f) `parserApply` xparser =
    Parser $ \state ->
        let (f, state')  = parse_f state
         in parse (fmap f xparser) state'
-}

{-  |
    Monad, finally! This is what lets us sequence operations, which in
    our Parser means sequencing the bits of the input that we read to
    produce a final result.

    Again, we need two functions: 'return' (not the same thing as
    @return@ in other languages!) and '>>=' (pronounced "bind").

    The 'return' function lifts pure values into the Monad structure.
    If this sounds familiar it's because we've already done this
    with 'Applicative': 'return' is simply 'pure'. In fact, that's
    the default definition in the standard library, but we define
    it in the exact same way ourselves here for clarity.

    As before we delay the discussion of '>>=' until after we've
    done the instance declaration.

    XXX from the docs:
    Instances of 'Monad' should satisfy the following laws:
    * @'return' a '>>=' k  =  k a@
    * @m '>>=' 'return'  =  m@
    * @m '>>=' (\\x -> k x '>>=' h)  =  (m '>>=' k) '>>=' h@

-}
instance Monad Parser where
    return :: a -> Parser a
    return = pure

    (>>=) :: Parser a -> (a -> Parser b) -> Parser b
    (>>=) = parserBind

{-  |
-}
parserBind :: Parser a -> (a -> Parser b) -> Parser b
_ `parserBind` _ = undefined

{-
    XXX We actually need to extend Parser to 'MonadFail' because
    'fail' (which handles failure in @do@ expressions) is going to be
    removed from 'Monad'. Plus we need failure anyway I'm pretty
    sure....
-}
