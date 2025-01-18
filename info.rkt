#lang info
(define collection "itertools")
(define deps '("base" "extra-srfi-libs"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/itertools.scrbl" ())))
(define pkg-desc "Python's itertools for Racket sequences")
(define version "0.3")
(define pkg-authors '(shawnw))
(define license '(Apache-2.0 OR MIT))
