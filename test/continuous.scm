(define-test (forward-normal-dist)
  (let ()
    (define samples (collect-samples `(begin ,gaussian-defn (normal 0 1))))
    (pp (list 'program-samples (sort samples <)))
    (check (> (k-s-test samples (lambda (x) (gaussian-cdf x 0 1))) 0.001))))

(define-test (forward-2-normal-dist)
  (let ()
    (define samples
      (collect-samples
       `(begin
          ,gaussian-defn
          (normal (normal 0 1) 1))))
    (pp (list 'program-samples (sort samples <)))
    (check (> (k-s-test samples (lambda (x) (gaussian-cdf x 0 2))) 0.001))))

(define-test (unrestricted-infer-normal-dist)
  (let ()
    (define samples
      (collect-samples
       `(begin
          ,map-defn
          ,mcmc-defn
          ,gaussian-defn
          (model-in (rdb-extend (get-current-trace))
            (assume mu (normal 0 1))
            (assume y (normal mu 1))
            (infer (mcmc 10))
            (predict mu)))))
    (pp (list 'program-samples (sort samples <)))
    (check (> (k-s-test samples (lambda (x) (gaussian-cdf x 0 1))) 0.001))))

(define-test (observed-normal-dist)
  (let ()
    (define samples (collect-samples (gaussian-example 20)))
    (pp (list 'program-samples (sort samples <)))
    (check (> (k-s-test samples (lambda (x) (gaussian-cdf x 1 (/ 1 (sqrt 2))))) 0.001))))