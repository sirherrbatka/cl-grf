(cl:in-package #:statistical-learning.isolation-forest)


(defun make-normals (count &optional (gaussian-state (sl.common:make-gauss-random-state)))
  (iterate
    (with result = (sl.data:make-data-matrix 1 count))
    (for i from 0 below count)
    (setf (sl.data:mref result 0 i)
          (sl.common:gauss-random gaussian-state))
    (finally (return result))))


(defun c-factor (n)
  (- (* 2.0d0 (+ +euler-constant+ (log (- n 1.0d0))))
     (/ (* 2.0d0 (- n 1.0d0))
        n)))
