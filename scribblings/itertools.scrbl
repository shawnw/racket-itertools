#lang scribble/manual
@require[@for-label[itertools
                    racket/base racket/list racket/sequence racket/undefined]]

@title{Python itertools... in Racket!}
@author[@author+email["Shawn Wagner" "shawnw.mobile@gmail.com"]]

@defmodule[itertools]

@section{Introduction}

This module implements the bits of the Python @hyperlink["https://docs.python.org/3/library/itertools.html"]{@tt{itertools} library} that aren't already present in one way or
another in Racket. The provided functions all work with sequences, which along with streams, are the closest things to Python iterables in Racket (But sequences
are much more fundamental to Racket, so that's what you get).

Conventions followed by this module: Functions that return a new, altered sequence have a @tt{in-} prefix, and ones that just filter existing
sequences start with @tt{sequence-}, which seems to be the general Racket practice. Where Python uses tuples, these functions instead generally return multiple values.
If you need a single value instead, wrap them in a list with @code{in-values-sequence}.

Select functions from the @hyperlink["https://pypi.org/project/more-itertools/"]{@tt{more-itertools} library} might make their way in here too; please
@hyperlink["https://github.com/shawnw/racket-itertools/issues"]{file issues} (And preferrably a pull request too) for any desired ones.

@section{itertools API}

@subsection{Infinite iterators}

@defproc[(in-count [start real? 0] [step real? 1]) (sequence/c real?)]{

 An infinite series of numbers, starting with @code{start} and incrementing by @code{step}. Equivalent to @tt{itertools.count}.

}

@bold{@tt{itertools.cycle}} is @code{in-cycle} in Racket.

@defproc[(in-repeat [val any/c] [n (or/c exact-nonnegative-integer? #f) #f]) (sequence/c any/c)]{

 Repeats @code{val} @code{n} times, or infinitely if the count is @code{#f}. Equivalent to @tt{itertools.repeat}.

}

@subsection{Iterators terminating on the shortest input sequence}

@defproc*[([(in-accumulate [seq (sequence/c any/c)] [f (-> any/c any/c any/c) +]) (sequence/c any/c)]
          [(in-accumulate [seq (sequence/c any/c)] [f (-> any/c any/c any/c)] [init any/c]) (sequence/c any/c)])]{

 Make a sequence that returns accumulated sums or accumulated results from other binary functions. If an initial value is provided,
 the accumulation will start with that value and the output will have one more element than the input sequence. Equivalent to @tt{itertools.accumulate}.

}

@bold{@tt{itertools.batched}} is @code{in-slice} in Racket.

@bold{@tt{itertools.chain}} is @code{in-sequences} in Racket.

@bold{@tt{itertools.chain.from_iterable}} is currently not implemented.

@defproc[(sequence-compress [data sequence?] [selectors (sequence/c any/c)]) sequence?]{

 Returns a new sequence of just the elements of @code{data} where the corresponding element of @code{selectors} is true. Equivalent to @tt{itertools.compress}.

}

@defproc[(sequence-drop-while [pred? procedure?] [seq sequence?]) sequence?]{

 Returns a new sequence whose first element is the first one of @code{seq} that makes @code{pred?} return @code{#f}.
 Works with multi-valued sequences; @code{pred?} should take as many arguments as the sequence has values.
 Equivalent to @tt{itertools.dropwhile}.

}

@defproc[(sequence-filter-not [pred? procedure?] [seq sequence?]) sequence?]{

 Like @code{sequence-filter} but keeps only elements for which @code{pred?} returns @code{#f}.
 Works with multi-valued sequences; @code{pred?} should take as many arguments as the sequence has values.
 Equivalent to @tt{itertools.filterfalse}.

}

@defproc[(in-group-by [seq? (sequence/c any/c)] [#:key key (-> any/c any/c) values] [#:equal? =? (-> any/c any/c any/c) equal?]) (sequence/c any/c list?)]{

 Groups series of consecutive elements that compare equal after being transformed by @code{key}. Each element of the resulting sequence has two values -
 the transformed value all elements of the group are grouped by, and the group itself, as a list of elements in the same order they appear in the original sequence.
 Equivalent to @tt{itertools.groupby}.

}

@bold{@tt{itertools.islice}} is currently not implemented.

@defproc[(in-pairwise [seq (sequence/c any/c)]) (sequence/c any/c any/c)]{

 Returns a two-valued sequence - the first and second elements of @code{seq}, the second and third elements, the third and fourth, and so on.
 If given a sequence of less than 2 elements, returns an empty sequence. Equivalent to @tt{itertools.pairwise}.

}

@bold{@tt{itertools.starmap}} is basically equivalent to @code{sequence-map} in Racket.

@defproc[(sequence-take-while [pred? procedure?] [seq sequence?]) sequence?]{

 Return a sequence of the leading elements of @code{seq} that make @code{pred?} return true.
 Works with multi-valued sequences; @code{pred?} should take as many arguments as the sequence has values.
 Equivalent to @tt{itertools.takewhile}.

}

@bold{@tt{itertools.tee}} is currently not implemented.

@defproc[(in-longest-parallel [seq (sequence/c any/c)] ... [#:fill-value fill any/c undefined]) sequence?]{

 Like @code{in-parallel}, but only stops after all sequences have been exhausted, not after the first. Sequences that end earlier are filled in with @code{fill}.
 Equivalent to @tt{itertools.zip_longest}.

}

@subsection{Combinatoric iterators}

@defproc[(in-cartesian-product [seq (sequence/c any/c)] ...) sequence?]{

 Returns a sequence that generates the cartesian product of the sequences it's passed. All those sequences should be
 finite. The resulting sequence has the same number of values as the number of arguments to the function.
 Equivalent to @tt{itertools.product}, though a @tt{repeat} argument is not currently supported.

}

@bold{@tt{itertools.permutations}} is basically @code{in-permutations} in Racket, though it doesn't support the optional length
argument of the Python iterator and only takes lists. A more Pythonic version is planned.

@bold{@tt{itertools.combinations}} is basically @code{in-combinations} in Racket, but only takes lists. A more Pythonic version is planned.

@bold{@tt{itertools.combinations_with_replacement}} is not currently implemented.

@section{Extras}

Additional functions not taken directly from @tt{itertools}.

@defproc[(sequence-take [seq sequence?] [len exact-nonnegative-integer?]) sequence?]{

Returns a sequence of the first @code{len} elements of @code{seq} (Or less if @code{seq} is a finite sequence with fewer elements).

}