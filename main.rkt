#lang racket/base

;;; Port of Python itertools functions that are missing from Racket sequences

(require racket/contract (only-in racket/list in-combinations in-permutations) racket/sequence racket/stream racket/undefined
         srfi/190 srfi/210 srfi/235)
(module+ test
  (require rackunit))

(provide
 in-cycle in-slice in-sequences in-combinations in-permutations
 sequence-map
 (contract-out
  [in-count (->* () (real? real?) sequence?)]
  [in-repeat (->* (any/c) ((or/c #f exact-nonnegative-integer?)) sequence?)]
  [in-accumulate (->* ((sequence/c any/c)) ((-> any/c any/c any/c) any/c) sequence?)]
  [sequence-compress (-> sequence? (sequence/c any/c) sequence?)]
  [sequence-drop-while (-> procedure? sequence? sequence?)]
  [sequence-filter-not (-> procedure? sequence? sequence?)]
  [in-group-by (->* ((sequence/c any/c)) (#:key (-> any/c any/c) #:equal? (-> any/c any/c any/c)) (sequence/c any/c list?))]
  [in-pairwise (-> (sequence/c any/c) (sequence/c any/c any/c))]
  [sequence-take-while (-> procedure? sequence? sequence?)]
  [in-longest-parallel (->* () (#:fill-value any/c) #:rest (listof (sequence/c any/c)) sequence?)]
  [in-cartesian-product (->* () () #:rest (listof (sequence/c any/c)) sequence?)]

  [sequence-take (-> sequence? exact-nonnegative-integer? sequence?)]
  ))

;;; count
(define (in-count [start 0] [step 1])
  (make-do-sequence
   (lambda ()
     (initiate-sequence
      #:pos->element values
      #:next-pos (lambda (prev) (+ prev step))
      #:init-pos start
      #:continue-with-pos? always))))

;;; cycle: in-cycle

;;; Return a sequence that takes the first count elements of seq
(define (sequence-take seq count)
  (make-do-sequence
   (lambda ()
     (define-values (more? get) (sequence-generate seq))
     (initiate-sequence
      #:pos->element (lambda (_) (get))
      #:next-pos add1
      #:init-pos 0
      #:continue-with-pos? (lambda (n) (and (< n count) (more?)))))))

;;; repeat
(define (in-repeat val [count #f])
  (make-do-sequence
   (lambda ()
     (initiate-sequence
      #:pos->element (constantly val)
      #:next-pos (if count add1 values)
      #:init-pos 0
      #:continue-with-pos? (if count (lambda (n) (< n count)) always)))))

;;; accumulate
(define in-accumulate
  (case-lambda
    [(seq) (in-accumulate seq +)]
    [(seq f)
     (make-do-sequence
      (lambda ()
        (define-values (more? get) (sequence-generate seq))
        (define total #f)
        (initiate-sequence
         #:pos->element (lambda (_)
                          (if total
                              (set-box! total (f (unbox total) (get)))
                              (set! total (box (get))))
                          (unbox total))
         #:next-pos values
         #:init-pos #t
         #:continue-with-pos? (lambda (_) (more?)))))]
    [(seq f init) (in-accumulate (sequence-append (in-value init) seq) f)]))

;;; batched: in-slice

;;; chain: in-sequences

;;; compress
(define (sequence-compress data selectors)
  (in-stream (for/stream ([d (in-values-sequence data)] [s selectors] #:when s) (list-values d))))

(define (initiate-empty-sequence)
  (initiate-sequence
   #:pos->element values
   #:next-pos values
   #:init-pos #f
   #:continue-with-pos? never))

;;; dropwhile
(define (sequence-drop-while pred? seq)
  (make-do-sequence
   (lambda ()
     (define-values (more? get) (sequence-generate seq))
     (let loop ()
       (if (more?)
           (let ([head-val (list/mv (get))])
             (if (apply pred? head-val)
                 (loop)
                 (initiate-sequence
                  #:pos->element
                  (lambda (first?)
                    (if first?
                        (begin0
                          (list-values head-val)
                          (set! head-val #f))
                        (get)))
                  #:next-pos never
                  #:init-pos #t
                  #:continue-with-pos? (lambda (first?) (if first? #t (more?))))))
           (initiate-empty-sequence))))))

;;; filterfalse
(define (sequence-filter-not pred? seq)
  (sequence-filter (complement pred?) seq))

;;;groupby
(define (in-group-by seq #:key [key values] #:equal? [=? equal?])
  (make-do-sequence
   (lambda ()
     (define-values (more? get) (sequence-generate seq))
     (define prev-key #f)
     (define prev '())
     (initiate-sequence
      #:pos->element
      (lambda (_)
        (let loop ([group prev])
          (cond
            [(more?)
             (let* ([next (get)]
                    [next-key (key next)])
               (if prev-key
                   (if (=? (unbox prev-key) next-key)
                       (loop (cons next group))
                       (begin0
                         (values (unbox prev-key) (reverse group))
                         (set-box! prev-key next-key)
                         (set! prev (list next))))
                   (begin
                     (set! prev-key (box next-key))
                     (loop (cons next group)))))]
            [prev-key
             (begin0
               (values (unbox prev-key) group)
               (set! prev-key #f)
               (set! prev '()))]
            [else
             (values #f #f)])))
      #:next-pos values
      #:init-pos #t
      #:continue-with-val? (lambda (key group) (pair? group))))))

;;; islice: not yet implemented

;;; pairwise
(define (in-pairwise seq)
  (make-do-sequence
   (lambda ()
     (define-values (more? get) (sequence-generate seq))
     (if (more?)
         (let ([first-val (get)])
           (if (more?)
               (initiate-sequence
                #:pos->element
                (lambda (_)
                  (define next-val (get))
                  (begin0
                    (values first-val next-val)
                    (set! first-val next-val)))
                #:next-pos values
                #:init-pos #t
                #:continue-with-pos? (lambda (_) (more?)))
               (initiate-empty-sequence)))
         (initiate-empty-sequence)))))

;;; starmap: sequence-map

;;; takewhile
(define (sequence-take-while pred? seq)
  (stop-before seq (complement pred?)))

;;; tee: not implemented

;;; zip_longest
(define (in-longest-parallel #:fill-value [fill undefined] . seqs)
  (cond
    [(null? seqs) empty-sequence] ; no sequences
    [(null? (cdr seqs)) (car seqs)] ; one sequence
    [else
     (make-do-sequence
      (lambda ()
        (define-values (more?s getters)
          (for/lists (more?s getters)
                     ([seq (in-list seqs)])
            (sequence-generate seq)))
        (initiate-sequence
         #:pos->element
         (lambda (_)
           (apply values (for/list ([more? (in-list more?s)]
                                    [get (in-list getters)])
                           (if (more?)
                               (get)
                               fill))))
         #:next-pos values
         #:init-pos #t
         #:continue-after-pos+val? (lambda _ (ormap (lambda (more?) (more?)) more?s)))))]))

;;; product
(define-coroutine-generator (generate-cartesian-products lol)
  (unless (null? lol)
    (let loop ([prod '()]
               [lol lol])
      (if (null? lol)
          (yield (reverse prod))
          (for ([curr (in-list (car lol))])
            (loop (cons curr prod) (cdr lol)))))))

(define (in-cartesian-product . seqs)
  (make-do-sequence
   (lambda ()
     (define next-cp (generate-cartesian-products (map sequence->list seqs)))
     (initiate-sequence
      #:pos->element list-values
      #:next-pos (lambda (_) (next-cp))
      #:init-pos (next-cp)
      #:continue-with-pos? (lambda (p) (not (eof-object? p)))))))
  
;;; permutations: in-permutations

;;; combinations: in-combinations

;;; combinations_with_replacement: not implemented

(module+ test
  (check-equal? (sequence->list (in-repeat 'a 5)) '(a a a a a))
  (check-equal? (sequence->list (sequence-take (in-repeat 'a) 6)) '(a a a a a a))

  (check-equal? (sequence->list (in-accumulate '(1 2 3 4 5))) '(1 3 6 10 15))
  (check-equal? (sequence->list (in-accumulate '(1 2 3 4 5) + 100)) '(100 101 103 106 110 115))
  (check-equal? (sequence->list (in-accumulate '(1 2 3 4 5) *)) '(1 2 6 24 120))

  (check-equal? (sequence->list (sequence-compress '(a b c d e f) '(#t #f #t #f #t #t))) '(a c e f))
  (check-equal? (for/list ([(v i) (sequence-compress (in-indexed '(a b c d e f)) '(#t #f #t #f #t #t))]) (add1 i)) '(1 3 5 6))

  (check-equal? (sequence->list (sequence-drop-while (lambda (x) (< x 5)) '(1 4 6 3 8))) '(6 3 8))
  (check-equal? (sequence->list (sequence-drop-while (lambda (x) (< x 5)) '(1 4 3))) '())
  (check-equal? (for/list ([(v i) (sequence-drop-while (lambda (v i) (< v 5)) (in-indexed '(1 4 6 3 8)))]) (list i v)) '((2 6) (3 3) (4 8)))
  
  (check-equal? (sequence->list (sequence-filter-not (lambda (x) (< x 5)) '(1 4 6 3 8))) '(6 8))
  (check-equal? (for/list ([(v i) (sequence-filter-not (lambda (v i) (odd? i)) (in-indexed '(1 2 3 4 5)))]) v) '(1 3 5))
  
  (check-equal? (for/list ([(key group) (in-group-by '#("a" "b" "def") #:key string-length)]) (list key group)) '((1 ("a" "b")) (3 ("def"))))
  (check-equal? (for/list ([(key group) (in-group-by '(A A A A B B B C C D A A B B B) #:equal? eq?)]) key) '(A B C D A B))

  (check-equal? (for/list ([(a b) (in-pairwise '(a b c d e f g))]) (list a b)) '((a b) (b c) (c d) (d e) (e f) (f g)))
  (check-equal? (for/list ([(a b) (in-pairwise empty-sequence)]) (list a b)) '())
  (check-equal? (for/list ([(a b) (in-pairwise '(a))]) (list a b)) '())

  (check-equal? (sequence->list (sequence-take-while (lambda (n) (< n 5)) '(1 4 6 3 8))) '(1 4))
  (check-equal? (sequence->list (sequence-take-while (lambda (n) (< n 5)) '(7 1 4 6 3 8))) '())

  (check-equal? (for/list ([(a b) (in-longest-parallel '(a b c d) '(x y) #:fill-value 'z)]) (list a b)) '((a x) (b y) (c z) (d z)))

  (check-equal? (for/list ([(a b) (in-cartesian-product '(a b c d) '(x y))]) (list a b)) '((a x) (a y) (b x) (b y) (c x) (c y) (d x) (d y)))
)
