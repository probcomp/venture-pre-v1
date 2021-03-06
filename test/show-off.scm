;;; Copyright (c) 2014 MIT Probabilistic Computing Project.
;;;
;;; This file is part of Venture.
;;;
;;; Venture is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; Venture is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Venture.  If not, see <http://www.gnu.org/licenses/>.

(in-test-group
 show-off

 (define-test (generate-truncated-gamma)
   (define program
     `(begin
        ,observe-defn
        (define standard-truncated-gamma
          (lambda (alpha)
            (model-in (rdb-extend (get-current-trace))
              (assume V (uniform 0 1))
              (assume X (expt V (/ 1 alpha)))
              (observe (flip (exp (- X))) #t)
              (infer rejection)
              (predict X))))
        (define truncated-gamma
          (lambda (alpha beta)
            (/ (standard-truncated-gamma alpha) beta)))
        (truncated-gamma 2 1)))
   (check (> (k-s-test (collect-samples program)
                       (lambda (x)
                         (/ ((gamma-cdf 2 1) x) ((gamma-cdf 2 1) 1))))
             *p-value-tolerance*)))

 (define-test (marsaglia-tsang-gamma)
   (define (marsaglia-tsang-gamma-program shape)
     `(begin
        ,exactly-defn
        ,observe-defn
        ,gaussian-defn
        (define marsaglia-standard-gamma-for-shape>1
          (lambda (alpha)
            (let ((d (- alpha 1/3)))
              (let ((c (/ 1 (sqrt (* 9 d)))))
                (model-in (rdb-extend (get-current-trace))
                  (assume x (normal 0 1))
                  (assume v (expt (+ 1 (* c x)) 3))
                  (observe (exactly (> v 0)) #t)
                  ;; Unless I use a short-circuit and between these
                  ;; two tests, this reject step is necessary to
                  ;; ensure that the next observation will not crash
                  ;; when forward-simulating for the first time.
                  (infer rejection)
                  (observe (exactly (< (log (uniform 0 1)) (+ (* 0.5 x x) (* d (+ 1 (- v) (log v)))))) #t)
                  (infer rejection)
                  (predict (* d v)))))))
        (marsaglia-standard-gamma-for-shape>1 ,shape)))
   (check (> (k-s-test (collect-samples (marsaglia-tsang-gamma-program 2)) (gamma-cdf 2 1))
             *p-value-tolerance*)))

 (define-test (gamma-assess)
   (define (assess-gamma x alpha beta)
     (+ (* alpha (log beta))
        (* (- alpha 1) (log x))
        (* -1 beta x)
        (* -1 (log-gamma alpha))))
   (for-each (lambda (x)
               (check (< (abs (- (/ (exp (assess-gamma x 1.2 2))
                                    ((gamma-pdf 1.2 2) x))
                                 1))
                         1e-10)))
             (map (lambda (x) (* 0.3 x)) (cdr (iota 100)))))

 (define-test (add-data-and-predict)
   (define program
     `(begin
        ,observe-defn
        ,map-defn
        ,mcmc-defn
        (model-in (rdb-extend (get-current-trace))
          (assume is-trick? (flip 0.1))
          (assume weight (if is-trick? (uniform 0 1) 0.5))
          (define add-data-and-infer
            (lambda ()
              ;; The trace in which this observe is run is
              ;; dynamically scoped right now
              (observe (flip weight) #t)
              (infer (mcmc 10))))
          (define find-trick
            (lambda ()
              (if (not (predict is-trick?))
                  (begin
                    (add-data-and-infer)
                    (find-trick))
                  'ok)))
          (find-trick)
          (predict weight))))
   ;; Check that it runs, but I have no idea what the distribution on
   ;; weights should be.
   (top-eval program))

 (define-test (convincability)
   (define library
     `(begin
        ,observe-defn
        ,map-defn
        ,mcmc-defn
        (define convincedness-sample-by-monte-carlo
          (lambda (prior trials steps)
            (model-in (rdb-extend (get-current-trace))
              (assume is-trick? (flip prior))
              (assume weight (if is-trick? (uniform 0 1) 0.5))
              (map (lambda (t)
                     (observe (flip weight) #t))
                   (iota trials))
              (infer (mcmc steps))
              (predict is-trick?))))
        (define estimate-truth-prob
          (lambda (thunk trials)
            (define trues-ct (list 0))
            (map (lambda (t)
                   (if (thunk)
                       (set-car! trues-ct (+ 1 (car trues-ct)))
                       'ok))
                 (iota trials))
            (/ (car trues-ct) trials)))
        (define convincedness-by-monte-carlo
          (lambda (prior trials steps trials*)
            (estimate-truth-prob
             (lambda ()
               (convincedness-sample-by-monte-carlo prior trials steps))
             trials*)))))
   (define (analytical-posterior prior trials)
     (let ((p+ (/ prior (+ trials 1)))
           (p- (/ (- 1 prior) (expt 2 trials))))
       (/ p+ (+ p+ p-))))
   (define (num-trials-to-convince prior level)
     (let loop ((answer 2))
       (if (> (analytical-posterior prior answer) level)
           answer
           (loop (+ answer 1)))))
   (define (prop-convincedness-correct prior trials)
     (let ((posterior (analytical-posterior prior trials)))
       (check (> (chi-sq-test
                  (collect-samples
                   `(begin ,library
                           (convincedness-sample-by-monte-carlo ,prior ,trials ,(* 5 trials))))
                  `((#t . ,posterior) (#f . ,(- 1 posterior))))
                 *p-value-tolerance*))))
   (prop-convincedness-correct 0.1 4)
   (prop-convincedness-correct 0.1 8)
   (prop-convincedness-correct 0.3 2)))
