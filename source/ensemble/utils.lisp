(cl:in-package #:statistical-learning.ensemble)


(defun weighted-sample (sample-size distribution)
  (map-into (make-array sample-size :element-type 'fixnum)
            distribution))


(defun bootstrap-sample (tree-sample-size data-points-count
                         distribution)
  (if (null distribution)
      (sl.data:select-random-indexes tree-sample-size
                                     data-points-count)
      (weighted-sample tree-sample-size distribution)))


(defun fit-tree-batch (parameters trees all-attributes
                       initargs train-data target-data
                       sampling-weights samples)
  (declare (optimize (debug 3)))
  (bind ((parallel (parallel parameters))
         (tree-sample-rate (tree-sample-rate parameters))
         (data-points-count (sl.data:data-points-count train-data))
         (tree-sample-size (floor (* tree-sample-rate data-points-count)))
         (distribution (if (null sampling-weights)
                           nil
                           (sl.random:discrete-distribution sampling-weights)))
         (tree-parameters (tree-parameters parameters))
         ((:flet make-model (attributes sample))
          (bind ((sub-state (apply #'sl.mp:make-training-state
                                   tree-parameters
                                   train-data
                                   target-data
                                   :attributes attributes
                                   :data-points sample
                                   initargs)))
            (sl.mp:make-model* tree-parameters
                               sub-state))))
    (map-into samples (curry #'bootstrap-sample
                             tree-sample-size data-points-count distribution))
    (funcall (if parallel #'lparallel:pmap-into #'map-into)
             trees
             #'make-model
             all-attributes
             samples)))


(defun contribute-trees (tree-parameters trees data parallel &optional state)
  (iterate
    (for tree in-vector trees)
    (setf state (statistical-learning.tp:contribute-predictions* tree-parameters
                                                   tree
                                                   data
                                                   state
                                                   parallel))
    (finally (return state))))


(defun trees-predict (tree-parameters trees data parallel &optional state)
  (let ((state (contribute-trees tree-parameters trees data parallel state)))
    (values (statistical-learning.tp:extract-predictions state)
            state)))
