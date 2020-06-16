(cl:in-package #:cl-user)


(defpackage #:statistical-learning.performance
  (:use #:cl #:statistical-learning.aux-package)
  (:nicknames #:sl.perf)
  (:export
   #:accuracy
   #:attributes-importance
   #:attributes-importance*
   #:at-confusion-matrix
   #:average-performance-metric
   #:cross-validation
   #:f1-score
   #:make-confusion-matrix
   #:performance-metric
   #:precision
   #:recall
   #:errors
   #:specificity
   #:classification
   #:regression
   #:two-class-confusion-matrix-from-general-confusion-matrix
   ))
