(cl:in-package #:cl-user)


(defpackage #:statistical-learning.common
  (:use #:cl #:statistical-learning.aux-package)
  (:nicknames #:sl.common)
  (:export
   #:next-proxy
   #:proxy
   #:defgeneric/proxy
   #:lifting-proxy
   #:lift
   #:random-uniform
   #:side-of-line
   #:gauss-random
   #:proxy-enabled))
