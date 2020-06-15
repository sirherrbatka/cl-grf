(cl:in-package #:statistical-learning.performance)


(defun cross-validation (model-parameters number-of-folds
                         train-data target-data parallel
                         &key weights
                         &allow-other-keys)
  (statistical-learning.data:check-data-points train-data target-data)
  (~> train-data
      statistical-learning.data:data-points-count
      (statistical-learning.data:cross-validation-folds number-of-folds)
      (cl-ds.alg:on-each
       (lambda (train.test)
         (bind (((train . test) train.test)
                ((:flet sampled-weights (sample))
                 (if (null weights)
                     nil
                     (map '(vector double-float)
                          (lambda (i) (aref weights i))
                          sample)))
                (model (statistical-learning.mp:make-model
                        model-parameters
                        (statistical-learning.data:sample train-data
                                            :data-points train)
                        (statistical-learning.data:sample target-data
                                                          :data-points train)
                        :weights (sampled-weights train)))
                (test-target-data (statistical-learning.data:sample target-data
                                                                    :data-points test))
                (test-train-data (statistical-learning.data:sample train-data
                                                                   :data-points test))
                (test-predictions (statistical-learning.mp:predict model
                                                                   test-train-data
                                                                   parallel)))
           (performance-metric model-parameters
                               test-target-data
                               test-predictions))))
      cl-ds.alg:to-vector
      (average-performance-metric model-parameters _)))


(defun attributes-importance* (model train-data target-data &optional parallel)
  (let* ((predictions (statistical-learning.mp:predict model train-data parallel))
         (model-parameters (statistical-learning.mp:parameters model))
         (errors (errors model-parameters
                         target-data
                         predictions)))
    (calculate-features-importance-from-permutations model
                                                     model-parameters
                                                     errors
                                                     train-data
                                                     target-data
                                                     parallel)))


(defun attributes-importance (model-parameters number-of-folds
                              train-data target-data &optional parallel)
  (statistical-learning.data:check-data-points train-data target-data)
  (~> train-data
      statistical-learning.data:data-points-count
      (statistical-learning.data:cross-validation-folds number-of-folds)
      (cl-ds.alg:on-each
       (lambda (train.test)
         (bind (((train . test) train.test)
                (train-train-data (statistical-learning.data:sample train-data
                                                       :data-points train))
                (train-target-data (statistical-learning.data:sample target-data
                                                       :data-points train))
                (model (statistical-learning.mp:make-model model-parameters
                                             train-train-data
                                             train-target-data))
                (test-target-data (statistical-learning.data:sample target-data
                                                      :data-points test))
                (test-train-data (statistical-learning.data:sample train-data
                                                     :data-points test)))
           (attributes-importance* model test-train-data
                                   test-target-data parallel))))
      cl-ds.alg:array-elementwise
      cl-ds.math:average))


(defun make-confusion-matrix (number-of-classes)
  (make-array (list number-of-classes number-of-classes)
              :element-type 'fixnum))


(defun number-of-classes (confusion-matrix)
  (array-dimension confusion-matrix 0))


(defun at-confusion-matrix (confusion-matrix expected-class predicted-class)
  (aref confusion-matrix expected-class predicted-class))


(defun (setf at-confusion-matrix) (new-value confusion-matrix
                                   expected-class predicted-class)
  (setf (aref confusion-matrix expected-class predicted-class)
        new-value))


(defun total (confusion-matrix)
  (iterate
    (for i from 0 below (array-total-size confusion-matrix))
    (sum (row-major-aref confusion-matrix i))))


(defun two-class-confusion-matrix-from-general-confusion-matrix
    (confusion-matrix class &optional (result (make-confusion-matrix 2)))
  (iterate
    (with number-of-classes = (array-dimension confusion-matrix 0))
    (for expected from 0 below number-of-classes)
    (for true/false = (if (= expected class) 1 0))
    (iterate
      (for predicted from 0 below number-of-classes)
      (for positive/negative = (if (= predicted class) 1 0))
      (incf (at-confusion-matrix result
                                 true/false
                                 positive/negative)
            (at-confusion-matrix confusion-matrix expected predicted)))
    (finally (return result))))


(defun fold-general-confusion-matrix (confusion-matrix)
  (iterate
    (with result = (make-confusion-matrix 2))
    (for i from 0 below (number-of-classes confusion-matrix))
    (two-class-confusion-matrix-from-general-confusion-matrix
     confusion-matrix
     i
     result)
    (finally (return result))))


(defun accuracy (confusion-matrix)
  (coerce (/ (iterate
               (for i from 0 below (array-dimension confusion-matrix 0))
               (sum (at-confusion-matrix confusion-matrix i i)))
             (total confusion-matrix))
          'double-float))


(defun recall (confusion-matrix)
  (let ((folded (fold-general-confusion-matrix confusion-matrix)))
    (coerce (/ (aref folded 1 1)
               (+ (aref folded 0 1)
                  (aref folded 1 1)))
            'double-float)))


(defun specificity (confusion-matrix)
  (let ((folded (fold-general-confusion-matrix confusion-matrix)))
    (coerce (/ (aref folded 0 0)
               (+ (aref folded 0 0)
                  (aref folded 0 1)))
            'double-float)))


(defun precision (confusion-matrix)
  (let ((folded (fold-general-confusion-matrix confusion-matrix)))
    (coerce (/ (aref folded 1 1)
               (+ (aref folded 1 0)
                  (aref folded 1 1)))
            'double-float)))


(defun f1-score (confusion-matrix)
  (coerce (/ 2 (+ (/ 1 (precision confusion-matrix))
                  (/ 1 (recall confusion-matrix))))
          'double-float))
