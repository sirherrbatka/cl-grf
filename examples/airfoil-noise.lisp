(cl:in-package #:cl-user)

(ql:quickload :cl-grf)
(ql:quickload :vellum)

(defpackage #:airfoil-noise-example
  (:use #:cl #:cl-grf.aux-package))

(cl:in-package #:airfoil-noise-example)

(defvar *data*
  (~> (vellum:copy-from :csv (~>> (asdf:system-source-directory :cl-grf)
                                  (merge-pathnames "examples/airfoil_self_noise.dat"))
                        :header nil
                        :separator #\tab)
      (vellum:to-table :columns '((:alias frequency :type float)
                                  (:alias angle :type float)
                                  (:alias chord-length :type float)
                                  (:alias velocity :type float)
                                  (:alias displacement :type float)
                                  (:alias sound :type float)))))

(defvar *train-data*
  (vellum:to-matrix (vellum:select *data* :columns '(:take-to displacement))
                    :element-type 'double-float))

(defvar *target-data*
  (vellum:to-matrix (vellum:select *data* :columns '(:v sound))
                    :element-type 'double-float))

(defparameter *training-parameters*
  (make 'cl-grf.algorithms:basic-regression
        :maximal-depth 4
        :minimal-difference 0.0001d0
        :minimal-size 5
        :trials-count 50
        :parallel nil))

(defparameter *forest-parameters*
  (make 'cl-grf.ensemble:random-forest-parameters
        :trees-count 500
        :parallel t
        :tree-batch-size 5
        :tree-attributes-count 5
        :tree-sample-rate 0.2
        :tree-parameters *training-parameters*))

(defparameter *mean-error*
  (cl-grf.performance:cross-validation *forest-parameters*
                                       4
                                       *train-data*
                                       *target-data*
                                       t))

(print *mean-error*) ; 16.943994007564303d0 (squared error, root equal 4.11630829841064d0)

(print (cl-grf.performance:cross-validation
        (make 'cl-grf.ensemble:gradient-boost-ensemble-parameters
              :trees-count 500
              :parallel t
              :tree-batch-size 10
              :tree-attributes-count 5
              :learning-rate 0.2d0
              :learning-rate-change (/ 0.4d0 200)
              :tree-sample-rate 0.1
              :tree-parameters (make 'cl-grf.alg:gradient-boost-regression
                                     :maximal-depth 5
                                     :minimal-size 5
                                     :minimal-difference 0.00001d0
                                     :trials-count 15
                                     :parallel nil))
        4
        *train-data*
        *target-data*
        t)) ; 3.8316703234121796d0 (also squared error, obviously a lot better)
