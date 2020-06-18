(cl:in-package #:statistical-learning.ensemble)


(defmethod initialize-instance :after
    ((instance ensemble)
     &rest initargs)
  (declare (ignore initargs))
  (let* ((trees-count (trees-count instance))
         (tree-batch-size (tree-batch-size instance))
         (parallel (parallel instance))
         (tree-attributes-count (tree-attributes-count instance))
         (tree-sample-rate (tree-sample-rate instance))
         (tree-parameters (tree-parameters instance)))
    (unless (< 0 tree-sample-rate 1.0)
      (error 'cl-ds:argument-value-out-of-bounds
             :value tree-sample-rate
             :bounds '(< 0 tree-sample-rate 1.0)
             :argument :tree-sample-rate))
    (unless (integerp tree-attributes-count)
      (error 'type-error
             :expected-type 'integer
             :datum tree-attributes-count))
    (unless (< 0 tree-attributes-count array-total-size-limit)
      (error 'cl-ds:argument-value-out-of-bounds
             :value tree-attributes-count
             :bounds `(< 0 :tree-attributes-count
                         ,array-total-size-limit)
             :argument :tree-attributes-count))
    (unless (typep tree-parameters
                   'statistical-learning.mp:fundamental-model-parameters)
      (error 'type-error
             :expected-type 'statistical-learning.mp:fundamental-model-parameters
             :datum tree-parameters))
    (unless (integerp trees-count)
      (error 'type-error :expected-type 'integer
                         :datum trees-count))
    (unless (integerp (/ trees-count tree-batch-size))
      (error 'cl-ds:incompatible-arguments
             :format-control ":TREES-COUNT is supposed to be multiple of :TREE-BATCH-SIZE"
             :parameters '(:tree-batch-size :trees-count)
             :values (list tree-batch-size trees-count)))
    (unless (< 0 trees-count array-total-size-limit)
      (error 'cl-ds:argument-value-out-of-bounds
             :value trees-count
             :bounds `(< 0 :trees-count
                         ,array-total-size-limit)
             :parameter :trees-count))))


(defmethod initialize-instance :after ((instance gradient-boost-ensemble)
                                       &rest initargs)
  (declare (ignore initargs))
  (let ((shrinkage (shrinkage instance))
        (shrinkage-change (shrinkage-change instance))
        (tree-batch-size (tree-batch-size instance))
        (trees-count (trees-count instance)))
    (check-type shrinkage double-float)
    (check-type shrinkage-change double-float)
    (unless (< (* (/ trees-count tree-batch-size)
                  shrinkage-change)
               shrinkage)
      (error 'cl-ds:incompatible-arguments
             :parameters '(:shrinkage :shrinkage-change)
             :values `(,shrinkage ,shrinkage-change)
             :format-control "SHRINKAGE-CHANGE value implies that SHRINKAGE will eventually go below zero."))))


(defmethod statistical-learning.mp:predict ((model ensemble-model)
                                            data
                                            &optional parallel)
  (check-type data statistical-learning.data:data-matrix)
  (let* ((trees (trees model))
         (parameters (statistical-learning.mp:parameters model))
         (tree-parameters (tree-parameters parameters))
         (result (trees-predict tree-parameters trees data parallel)))
    result))


(defmethod weights-calculator
    ((training-parameters random-forest)
     (tree-parameters sl.perf:classification)
     parallel
     weights
     train-data
     target-data)
  (let* ((length (sl.data:data-points-count train-data))
         (state nil))
    (declare (type fixnum length))
    (lambda (prev-trees base)
      (declare (optimize (speed 3) (safety 0))
               (type vector prev-trees)
               (type fixnum base))
      (declare (ignore base))
      (bind (((:values predictions new-state)
              (trees-predict tree-parameters
                             prev-trees
                             train-data
                             parallel
                             state)))
        (declare (type statistical-learning.data:data-matrix predictions))
        (setf state new-state)
        (iterate
          (declare (type fixnum i))
          (for i from 0 below length)
          (for expected = (sl.data:mref target-data i 0))
          (for prediction = (statistical-learning.data:mref predictions
                                                            i
                                                            (truncate expected)))
          (setf (sl.data:mref weights i 0)
                (+ double-float-epsilon
                   (abs (- (sl.data:mref predictions i 0)
                           expected)))))
        weights))))


(defmethod weights-calculator
    ((training-parameters random-forest)
     (tree-parameters sl.perf:regression)
     parallel
     weights
     train-data
     target-data)
  (let ((data-points-count (sl.data:data-points-count train-data))
        (state nil))
    (declare (type fixnum data-points-count))
    (lambda (prev-trees base)
      (declare (ignore base)
               (optimize (speed 3) (safety 0)))
      (bind (((:values predictions new-state)
              (trees-predict tree-parameters
                             prev-trees
                             train-data
                             parallel
                             state)))
        (setf state new-state)
        (iterate
          (declare (type fixnum i))
          (for i from 0 below data-points-count)
          (setf (sl.data:mref weights i 0)
                (+ double-float-epsilon
                   (abs (- (sl.data:mref predictions i 0)
                           (sl.data:mref target-data i 0)))))))
      weights)))


(defmethod sl.mp:make-model* ((parameters random-forest)
                              state)
  (bind ((train-data (sl.mp:training-data state))
         (weights (sl.mp:weights state))
         (target-data (sl.mp:target-data state))
         (tree-batch-size (tree-batch-size parameters))
         (tree-parameters (tree-parameters parameters))
         (trees-count (trees-count parameters))
         (parallel (parallel parameters))
         (tree-attributes-count (tree-attributes-count parameters))
         (trees (make-array trees-count))
         (samples (make-array trees-count))
         (attributes (make-array trees-count))
         (weights-calculator nil)
         ((:flet array-view (array &key (from 0) (to trees-count)))
          (make-array (min trees-count (- to from))
                      :displaced-index-offset (min trees-count from)
                      :displaced-to array)))
    (statistical-learning.data:bind-data-matrix-dimensions
        ((train-data-data-points train-data-attributes train-data)
         (target-data-data-points target-data-attributes target-data))
      (setf weights (if (null weights)
                        (sl.data:make-data-matrix train-data-data-points
                                                  1
                                                  1.0d0)
                        (copy-array weights)))
      (setf weights-calculator (weights-calculator parameters tree-parameters
                                                   parallel weights
                                                   train-data target-data))
      (~>> (sl.data:selecting-random-indexes tree-attributes-count
                                             train-data-attributes)
           (map-into attributes))
      (iterate
        (with all-attributes = (~>  train-data sl.data:attributes-count
                                    sl.data:iota-vector))
        (with tree-training-state =
              (sl.mp:make-training-state tree-parameters
                                         train-data
                                         target-data
                                         :attributes all-attributes))
        (for base from (+ 2 (/ trees-count tree-batch-size)) downto 0)
        (for index from 0
             below trees-count
             by tree-batch-size)
        (for trees-view = (array-view trees
                                      :from index
                                      :to (+ index tree-batch-size)))
        (for attributes-view = (array-view attributes
                                           :from index
                                           :to (+ index tree-batch-size)))
        (for samples-view = (array-view samples
                                        :from index
                                        :to (+ index tree-batch-size)))
        (fit-tree-batch parameters trees-view attributes-view
                        tree-training-state weights samples-view)
        (funcall weights-calculator trees-view base))
      (make 'random-forest-model
            :trees trees
            :parameters parameters
            :target-attributes-count target-data-attributes))))


(defmethod sl.mp:make-model* ((parameters gradient-boost-ensemble)
                              state)
  (bind ((train-data (sl.mp:training-data state))
         (weights (sl.mp:weights state))
         (target-data (sl.mp:target-data state))
         (train-data-attributes (sl.data:attributes-count train-data))
         (target-data-attributes (sl.data:attributes-count target-data))
         (tree-batch-size (tree-batch-size parameters))
         (tree-parameters (tree-parameters parameters))
         (trees-count (trees-count parameters))
         (samples (make-array trees-count))
         (parallel (parallel parameters))
         (tree-attributes-count (tree-attributes-count parameters))
         (trees (make-array trees-count))
         (attributes (make-array trees-count))
         ((:flet array-view (array &key (from 0) (to trees-count)))
          (make-array (min trees-count (- to from))
                      :displaced-index-offset (min trees-count from)
                      :displaced-to array))
         (expected-value (statistical-learning.gradient-boost-tree:calculate-expected-value
                          tree-parameters
                          target-data)))
    (~>> (sl.data:selecting-random-indexes tree-attributes-count
                                           train-data-attributes)
         (map-into attributes))
    (iterate
      (with all-attributes = (sl.data:iota-vector train-data-attributes))
      (with shrinkage = (shrinkage parameters))
      (with shrinkage-change = (shrinkage-change parameters))
      (with response = nil)
      (with state = nil)
      (for index from 0
           below trees-count
           by tree-batch-size)
      (for trees-view = (array-view trees
                                    :from index
                                    :to (+ index tree-batch-size)))
      (for attributes-view = (array-view attributes
                                         :from index
                                         :to (+ index tree-batch-size)))
      (for samples-view = (array-view samples
                                      :from index
                                      :to (+ index tree-batch-size)))
      (for tree-training-state = (sl.mp:make-training-state tree-parameters
                                                            train-data
                                                            target-data
                                                            :weights weights
                                                            :expected-value expected-value
                                                            :attributes all-attributes
                                                            :response response
                                                            :shrinkage shrinkage))
      (fit-tree-batch parameters trees-view attributes-view
                      tree-training-state nil samples-view)
      (for new-state = (contribute-trees tree-parameters
                                         trees-view
                                         train-data
                                         parallel
                                         state))
      (decf shrinkage shrinkage-change)
      (setf response (sl.gbt:calculate-response tree-parameters
                                                new-state
                                                target-data)
            state new-state))
    (make 'gradient-boost-ensemble-model
          :trees trees
          :parameters parameters
          :target-attributes-count target-data-attributes)))


(defmethod sl.perf:performance-metric ((parameters ensemble)
                                       target
                                       predictions
                                       &key weights)
  (sl.perf:performance-metric (tree-parameters parameters)
                              target
                              predictions
                              :weights weights))


(defmethod sl.perf:average-performance-metric ((parameters ensemble)
                                               metrics)
  (sl.perf:average-performance-metric (tree-parameters parameters)
                                      metrics))


(defmethod sl.perf:errors ((parameters ensemble)
                           target
                           predictions)
  (sl.perf:errors (tree-parameters parameters)
                  target
                  predictions))
