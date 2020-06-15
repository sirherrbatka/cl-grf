(cl:in-package #:statistical-learning.algorithms)


(defmethod calculate-score ((training-parameters single-impurity-classification)
                            split-array
                            state)
  (split-impurity training-parameters
                  split-array
                  (sl.tp:target-data state)))


(defmethod sl.tp:split* :around
    ((training-parameters scored-classification)
     training-state
     leaf)
  (when (<= (score leaf)
            (~> training-parameters minimal-difference))
    (return-from sl.tp:split* nil))
  (call-next-method))


(defmethod sl.tp:split*
    ((training-parameters scored-training)
     training-state
     leaf)
  (declare (optimize (speed 3) (safety 0)))
  (bind ((training-data (sl.tp:training-data training-state))
         (trials-count (sl.tp:trials-count training-parameters))
         (minimal-difference (minimal-difference training-parameters))
         (score (score leaf))
         (minimal-size (sl.tp:minimal-size training-parameters))
         (parallel (sl.tp:parallel training-parameters))
         (attributes (sl.tp:attribute-indexes training-state)))
    (declare (type fixnum trials-count)
             (type double-float score minimal-difference)
             (type boolean parallel))
    (iterate
      (declare (type fixnum attempt left-length right-length
                     optimal-left-length optimal-right-length
                     optimal-attribute data-size)
               (type double-float
                     left-score right-score
                     minimal-score optimal-threshold))
      (with optimal-left-length = -1)
      (with optimal-right-length = -1)
      (with optimal-attribute = -1)
      (with minimal-score = most-positive-double-float)
      (with minimal-left-score = most-positive-double-float)
      (with minimal-right-score = most-positive-double-float)
      (with optimal-threshold = most-positive-double-float)
      (with data-size = (sl.data:data-points-count training-data))
      (with split-array = (make-array data-size :element-type 'boolean
                                                :initial-element nil))
      (with optimal-array = (make-array data-size :element-type 'boolean
                                                  :initial-element nil))
      (for attempt from 0 below trials-count)
      (for (values attribute threshold) = (random-test attributes training-data))
      (for (values left-length right-length) = (fill-split-array
                                                training-data
                                                attribute
                                                threshold
                                                split-array))
      (when (or (< left-length minimal-size)
                (< right-length minimal-size))
        (next-iteration))
      (for (values left-score right-score) = (calculate-score
                                              training-parameters
                                              split-array
                                              training-state))
      (for split-score = (+ (* (/ left-length data-size) left-score)
                            (* (/ right-length data-size) right-score)))
      (when (< split-score minimal-score)
        (setf minimal-score split-score
              optimal-threshold threshold
              optimal-attribute attribute
              optimal-left-length left-length
              optimal-right-length right-length
              minimal-left-score left-score
              minimal-right-score right-score)
        (rotatef split-array optimal-array))
      (finally
       (let ((difference (- (the double-float score)
                            (the double-float minimal-score))))
         (declare (type double-float difference))
         (when (< difference minimal-difference)
           (return nil))
         (let ((new-attributes (subsample-vector attributes
                                                 optimal-attribute)))
           (return (make 'scored-tree-node
                         :left-node (make-simple-node
                                     optimal-array
                                     minimal-left-score
                                     optimal-left-length
                                     nil
                                     parallel
                                     training-state
                                     new-attributes
                                     optimal-attribute)
                         :right-node (make-simple-node
                                      optimal-array
                                      minimal-right-score
                                      optimal-right-length
                                      t
                                      nil
                                      training-state
                                      new-attributes
                                      optimal-attribute)
                         :support data-size
                         :score score
                         :attribute (aref attributes optimal-attribute)
                         :attribute-value optimal-threshold))))))))



(defmethod sl.tp:make-leaf* ((training-parameters single-impurity-classification)
                             training-state)
  (declare (optimize (speed 3)))
  (let* ((target-data (sl.tp:target-data training-state))
         (number-of-classes (number-of-classes training-parameters))
         (data-points-count (sl.data:data-points-count target-data))
         (score (sl.tp:loss training-state))
         (predictions (sl.data:make-data-matrix 1 number-of-classes)))
    (declare (type fixnum number-of-classes data-points-count)
             (type statistical-learning.data:data-matrix target-data predictions))
    (iterate
      (declare (type fixnum i index))
      (for i from 0 below data-points-count)
      (for index = (truncate (sl.data:mref target-data i 0)))
      (incf (sl.data:mref predictions 0 index)))
    (make-instance 'scored-leaf-node
                   :support (sl.data:data-points-count target-data)
                   :predictions predictions
                   :score score)))


(defmethod sl.tp:make-leaf* ((training-parameters gradient-boost-classification)
                             training-state)
  (declare (optimize (speed 3) (safety 0)))
  (let* ((target-data (sl.tp:target-data training-state))
         (score (sl.tp:loss training-state))
         (data-points-count (sl.data:data-points-count target-data)))
    (declare (type fixnum data-points-count))
    (make-instance
     'scored-leaf-node
     :support (sl.data:data-points-count target-data)
     :predictions (~>> (statistical-learning.data:reduce-data-points #'+ target-data)
                       (statistical-learning.data:map-data-matrix (lambda (x)
                                                                    (/ x data-points-count))))
     :score score)))


(defmethod sl.tp:make-leaf* ((training-parameters regression)
                             training-state)
  (declare (optimize (speed 3) (safety 0)))
  (let* ((target-data (sl.tp:target-data training-state))
         (score (sl.tp:loss training-state))
         (data-points-count (sl.data:data-points-count target-data)))
    (declare (type fixnum data-points-count))
    (iterate
      (declare (type fixnum i)
               (type double-float sum))
      (with sum = 0.0d0)
      (for i from 0 below data-points-count)
      (incf sum (sl.data:mref target-data i 0))
      (finally (return (make-instance
                        'scored-leaf-node
                        :support (sl.data:data-points-count target-data)
                        :predictions (/ sum data-points-count)
                        :score score))))))


(defmethod statistical-learning.mp:make-model ((parameters gradient-boost-classification)
                                               train-data
                                               target-data
                                               &key attributes
                                                 expected-value
                                                 response
                                                 shrinkage
                                                 weights
                                               &allow-other-keys)
  (let* ((number-of-classes (number-of-classes parameters))
         (data-points-count (sl.data:data-points-count target-data))
         (target
           (if (null response)
               (iterate
                 (with result = (sl.data:make-data-matrix
                                 data-points-count
                                 number-of-classes))
                 (for i from 0 below data-points-count)
                 (for target = (truncate (sl.data:mref target-data i 0)))
                 (iterate
                   (for j from 0 below number-of-classes)
                   (setf (sl.data:mref result i j)
                         (- (if (= target j) 1 0)
                            (sl.data:mref expected-value 0 j))))
                 (finally (return result)))
               response))
         (state (make 'gradient-boost-training-state
                      :shrinkage shrinkage
                      :training-parameters parameters
                      :attribute-indexes attributes
                      :target-data target
                      :number-of-classes number-of-classes
                      :weights weights
                      :loss (~> (make-array data-points-count
                                            :element-type 'boolean
                                            :initial-element nil)
                                (regression-score target))
                      :training-data train-data))
         (leaf (sl.tp:make-leaf state))
         (tree (sl.tp:split state leaf)))
    (make 'gradient-boost-model
          :parameters parameters
          :shrinkage shrinkage
          :expected-value expected-value
          :root (if (null tree) leaf tree))))


(defmethod statistical-learning.mp:make-model ((parameters gradient-boost-regression)
                                               train-data
                                               target-data
                                               &key attributes
                                                 expected-value
                                                 response
                                                 shrinkage
                                                 weights
                                               &allow-other-keys)
  (let* ((target
           (if (null response)
               (statistical-learning.data:map-data-matrix (lambda (x)
                                                            (- x expected-value))
                                                          target-data)
               response))
         (data-points-count (sl.data:data-points-count target-data))
         (state (make 'gradient-boost-training-state
                      :shrinkage shrinkage
                      :training-parameters parameters
                      :attribute-indexes attributes
                      :weights weights
                      :loss (~> (make-array data-points-count
                                            :element-type 'boolean
                                            :initial-element nil)
                                (regression-score target))
                      :target-data target
                      :training-data train-data))
         (leaf (sl.tp:make-leaf state))
         (tree (sl.tp:split state leaf)))
    (make 'gradient-boost-model
          :parameters parameters
          :shrinkage shrinkage
          :expected-value expected-value
          :root (if (null tree) leaf tree))))


(defmethod calculate-expected-value ((parameters regression) data)
  (~> data cl-ds.utils:unfold-table mean))


(defmethod calculate-expected-value ((parameters classification) data)
  (iterate
    (with result = (~>> parameters number-of-classes
                        (sl.data:make-data-matrix 1)))
    (for i from 0 below (sl.data:data-points-count data))
    (iterate
      (for j from 0 below (statistical-learning.data:attributes-count data))
      (incf (sl.data:mref result 0
                          (truncate (sl.data:mref data i 0)))))
    (finally
     (iterate
       (for j from 0 below (statistical-learning.data:attributes-count data))
       (for avg = (/ #1=(sl.data:mref result 0 j)
                     (sl.data:data-points-count data)))
       (setf #1# avg))
     (return result))))


(defmethod gradient-boost-response* ((parameters gradient-boost-classification)
                                     expected
                                     predicted)
  (declare (optimize (speed 3) (safety 0))
           (type statistical-learning.data:data-matrix expected))
  (iterate
    (declare (type fixnum i number-of-classes)
             (type statistical-learning.data:data-matrix sums result))
    (with sums = (sums predicted))
    (with number-of-classes = (number-of-classes parameters))
    (with result = (statistical-learning.data:make-data-matrix-like sums))
    (for i from 0 below (sl.data:data-points-count expected))
    (iterate
      (declare (type fixnum j))
      (for j from 0 below number-of-classes)
      (setf (sl.data:mref result i j)
            (- (if (= (coerce j 'double-float)
                      (sl.data:mref expected i 0))
                   1.0d0
                   0.0d0)
               (sl.data:mref sums i j))))
    (finally (return result))))


(defmethod gradient-boost-response* ((parameters gradient-boost-regression)
                                     expected
                                     gathered-predictions)
  (declare (optimize (speed 3) (safety 0)))
  (let ((predicted (sl.tp:extract-predictions gathered-predictions)))
    (statistical-learning.data:check-data-points expected predicted)
    (iterate
      (declare (type fixnum i))
      (with result = (statistical-learning.data:make-data-matrix-like expected))
      (for i from 0 below (sl.data:data-points-count result))
      (setf (sl.data:mref result i 0)
            (- (sl.data:mref expected i 0)
               (sl.data:mref predicted i 0)))
      (finally (return result)))))


(defmethod statistical-learning.mp:make-model ((parameters scored-training)
                                               train-data
                                               target-data
                                               &key attributes weights &allow-other-keys)
  (let* ((data-points-count (sl.data:data-points-count target-data))
         (state (make 'sl.tp:fundamental-training-state
                      :training-parameters parameters
                      :loss 0.0d0
                      :weights weights
                      :attribute-indexes attributes
                      :target-data target-data
                      :training-data train-data))
         (score (~> data-points-count
                    (make-array :initial-element nil
                                :element-type 'boolean)
                    (calculate-score parameters
                                     _
                                     state))))
    (setf (sl.tp:loss state) score)
    (make 'sl.tp:tree-model
          :parameters parameters
          :root (let ((leaf (sl.tp:make-leaf state)))
                  (or (sl.tp:split state leaf) leaf)))))


(defmethod initialize-instance :after ((parameters single-impurity-classification)
                                       &rest initargs)
  (declare (ignore initargs))
  (let ((number-of-classes (number-of-classes parameters)))
    (unless (integerp number-of-classes)
      (error 'type-error
             :expected-type 'integer
             :datum number-of-classes))
    (when (< number-of-classes 2)
      (error 'cl-ds:argument-value-out-of-bounds
             :bounds '(>= :number-of-classes 2)
             :value number-of-classes
             :argument :number-of-classes
             :format-control "Classification requires at least 2 classes for classification."))))


(defmethod statistical-learning.performance:performance-metric
    ((parameters classification)
     target
     predictions
     &key weights)
  (sl.data:check-data-points target predictions)
  (bind ((number-of-classes (the fixnum (number-of-classes parameters)))
         (data-points-count (sl.data:data-points-count target))
         ((:flet prediction (prediction))
          (declare (optimize (speed 3) (safety 0)))
          (iterate
            (declare (type fixnum i))
            (for i from 0 below number-of-classes)
            (finding i maximizing (sl.data:mref predictions prediction i))))
         (result (statistical-learning.performance:make-confusion-matrix number-of-classes)))
    (iterate
      (declare (type fixnum i)
               (optimize (speed 3)))
      (for i from 0 below data-points-count)
      (for expected = (truncate (sl.data:mref target i 0)))
      (for predicted = (prediction i))
      (incf (sl.perf:at-confusion-matrix result expected predicted)
            (if (null weights)
                1.0d0
                (aref weights i))))
    result))


(defmethod sl.perf:average-performance-metric
    ((parameters classification)
     metrics)
  (iterate
    (with result = (~> parameters number-of-classes
                       sl.perf:make-confusion-matrix))
    (for i from 0 below (length metrics))
    (for confusion-matrix = (aref metrics i))
    (sum-matrices confusion-matrix result)
    (finally (return result))))


(defmethod sl.perf:errors ((parameters classification)
                           target
                           predictions)
  (declare (optimize (speed 3) (safety 0))
           (type simple-vector predictions)
           (type statistical-learning.data:data-matrix target))
  (let* ((data-points-count (sl.data:data-points-count target))
         (result (make-array data-points-count :element-type 'double-float)))
    (declare (type (simple-array double-float (*)) result))
    (iterate
      (declare (type fixnum i))
      (for i from 0 below data-points-count)
      (for expected = (truncate (sl.data:mref target i 0)))
      (setf (aref result i) (- 1.0d0 (sl.data:mref predictions
                                                   i
                                                   expected))))
    result))


(defmethod sl.perf:errors ((parameters regression)
                           target
                           predictions)
  (iterate
    (with result = (make-array (sl.data:data-points-count predictions)
                               :element-type 'double-float
                               :initial-element 0.0d0))
    (for i from 0 below (sl.data:data-points-count predictions))
    (for er = (- (sl.data:mref target i 0)
                 (sl.data:mref predictions i 0)))
    (setf (aref result i) (* er er))
    (finally (return result))))


(defmethod sl.perf:performance-metric ((parameters regression)
                                       target
                                       predictions
                                       &key weights)
  (iterate
    (with sum = 0.0d0)
    (with count = (sl.data:data-points-count predictions))
    (for i from 0 below count)
    (for er = (- (sl.data:mref target i 0)
                 (sl.data:mref predictions i 0)))
    (incf sum (* (if (null weights) 1.0d0 (aref weights i))
                 (* er er)))
    (finally (return (/ sum count)))))


(defmethod sl.perf:average-performance-metric ((parameters regression)
                                               metrics)
  (mean metrics))


(defmethod sl.tp:contribute-predictions* ((parameters single-impurity-classification)
                                          model
                                          data
                                          state
                                          parallel)
  (statistical-learning.data:bind-data-matrix-dimensions ((data-points-count attributes-count data))
    (let ((number-of-classes (number-of-classes parameters)))
      (when (null state)
        (setf state (make 'gathered-predictions
                          :indexes (sl.data:iota-vector data-points-count)
                          :training-parameters parameters
                          :sums (sl.data:make-data-matrix data-points-count
                                                          number-of-classes))))
      (let* ((sums (sums state))
             (root (sl.tp:root model)))
        (funcall (if parallel #'lparallel:pmap #'map)
                 nil
                 (lambda (data-point)
                   (iterate
                     (declare (type fixnum j))
                     (with leaf = (sl.tp:leaf-for root data data-point))
                     (with predictions = (predictions leaf))
                     (with support = (support leaf))
                     (for j from 0 below number-of-classes)
                     (for class-support = (sl.data:mref predictions 0 j))
                     (incf (sl.data:mref sums data-point j)
                           (/ class-support support))))
                 (indexes state))))
    (incf (contributions-count state))
    state))


(defmethod sl.tp:contribute-predictions* ((parameters basic-regression)
                                          model
                                          data
                                          state
                                          parallel)
  (statistical-learning.data:bind-data-matrix-dimensions ((data-points-count attributes-count data))
    (when (null state)
      (setf state (make 'gathered-predictions
                        :indexes (sl.data:iota-vector data-points-count)
                        :training-parameters parameters
                        :sums (sl.data:make-data-matrix data-points-count
                                                        1))))
    (let* ((sums (sums state))
           (root (sl.tp:root model)))
      (funcall (if parallel #'lparallel:pmap #'map)
               nil
               (lambda (data-point)
                 (let* ((leaf (sl.tp:leaf-for root data data-point))
                        (predictions (predictions leaf)))
                   (incf (sl.data:mref sums data-point 0)
                         predictions)))
               (indexes state)))
    (incf (contributions-count state))
    state))


(defmethod sl.tp:contribute-predictions* ((parameters gradient-boost-regression)
                                          model
                                          data
                                          state
                                          parallel)
  (statistical-learning.data:bind-data-matrix-dimensions ((data-points-count attributes-count data))
    (when (null state)
      (setf state (make 'gathered-predictions
                        :indexes (sl.data:iota-vector data-points-count)
                        :training-parameters parameters
                        :sums (sl.data:make-data-matrix data-points-count
                                                        1
                                                        (expected-value model)))))
    (let* ((sums (sums state))
           (shrinkage (shrinkage model))
           (root (sl.tp:root model)))
      (funcall (if parallel #'lparallel:pmap #'map)
               nil
               (lambda (data-point)
                 (let* ((leaf (sl.tp:leaf-for root data data-point))
                        (predictions (predictions leaf)))
                   (incf (sl.data:mref sums data-point 0)
                         (* shrinkage predictions))))
               (indexes state)))
    (incf (contributions-count state))
    state))


(defmethod sl.tp:contribute-predictions* ((parameters gradient-boost-classification)
                                          model
                                          data
                                          state
                                          parallel)
  (statistical-learning.data:bind-data-matrix-dimensions ((data-points-count attributes-count data))
    (when (null state)
      (setf state (make 'gathered-predictions
                        :indexes (sl.data:iota-vector data-points-count)
                        :training-parameters parameters
                        :sums (sl.data:make-data-matrix data-points-count
                                                                          (number-of-classes parameters)))))
    (let* ((sums (sums state))
           (number-of-classes (number-of-classes parameters))
           (shrinkage (shrinkage model))
           (root (sl.tp:root model)))
      (funcall (if parallel #'lparallel:pmap #'map)
               nil
               (lambda (data-point)
                 (iterate
                   (declare (type fixnum j))
                   (with leaf = (sl.tp:leaf-for root data data-point))
                   (with predictions = (predictions leaf))
                   (for j from 0 below number-of-classes)
                   (for gradient = (sl.data:mref predictions 0 j))
                   (incf (sl.data:mref sums data-point j)
                         (* shrinkage gradient))))
               (indexes state)))
    (incf (contributions-count state))
    state))


(defmethod sl.tp:extract-predictions* ((parameters basic-regression)
                                       (state gathered-predictions))
  (let ((count (contributions-count state)))
    (statistical-learning.data:map-data-matrix (lambda (value) (/ value count))
                                               (sums state))))


(defmethod sl.tp:extract-predictions* ((parameters single-impurity-classification)
                                       (state gathered-predictions))
  (let ((count (contributions-count state)))
    (statistical-learning.data:map-data-matrix (lambda (value) (/ value count))
                                               (sums state))))


(defmethod sl.tp:extract-predictions* ((parameters gradient-boost-regression)
                                       (state gathered-predictions))
  (sums state))


(defmethod sl.tp:extract-predictions* ((parameters gradient-boost-classification)
                                       (state gathered-predictions))
  (declare (optimize (speed 3) (debug 0) (safety 0)))
  (iterate
    (declare (type fixnum i number-of-classes)
             (type double-float maximum sum)
             (type statistical-learning.data:data-matrix sums result))
    (with number-of-classes = (number-of-classes parameters))
    (with sums = (sums state))
    (with result = (statistical-learning.data:make-data-matrix-like sums))
    (for i from 0 below (sl.data:data-points-count sums))
    (for maximum = most-negative-double-float)
    (for sum = 0.0d0)
    (iterate
      (declare (type fixnum j))
      (for j from 0 below number-of-classes)
      (maxf maximum (sl.data:mref sums i j)))
    (iterate
      (declare (type fixnum j)
               (type double-float out))
      (for j from 0 below number-of-classes)
      (for out = (exp (- (sl.data:mref sums i j) maximum)))
      (setf (sl.data:mref result i j) out)
      (incf sum out))
    (iterate
      (declare (type fixnum j))
      (for j from 0 below number-of-classes)
      (setf #1=(sl.data:mref result i j) (/ #1# sum)))
    (finally (return result))))


(-> regression-score ((simple-array boolean (*))
                      statistical-learning.data:data-matrix
                      &optional (or null (simple-array double-float (*))))
    double-float)
(defun regression-score (split-array target-data &optional weights)
  (declare (optimize (speed 3) (safety 0) (debug 0)))
  (cl-ds.utils:cases ((null weights))
    (let ((left-sum 0.0d0)
          (right-sum 0.0d0)
          (left-count 0)
          (right-count 0))
      (declare (type double-float left-sum right-sum)
               (type statistical-learning.data:data-matrix target-data)
               (type fixnum left-count right-count))
      (iterate
        (declare (type fixnum i))
        (for i from 0 below (length split-array))
        (for right-p = (aref split-array i))
        (for value = (sl.data:mref target-data i 0))
        (if right-p
            (setf right-count (1+ right-count)
                  right-sum (+ right-sum value))
            (setf left-count (1+ left-count)
                  left-sum (+ left-sum value))))
      (iterate
        (declare (type double-float
                       left-error right-error
                       left-avg right-avg)
                 (type fixnum i))
        (with left-error = 0.0d0)
        (with right-error = 0.0d0)
        (with left-avg = (if (zerop left-count)
                             0.0d0
                             (/ left-sum left-count)))
        (with right-avg = (if (zerop right-count)
                              0.0d0
                              (/ right-sum right-count)))
        (for i from 0 below (length split-array))
        (for rightp = (aref split-array i))
        (for value = (sl.data:mref target-data i 0))
        (if rightp
            (incf right-error (square (if (null weights)
                                          #1=(- value right-avg)
                                          (* (aref weights i) #1#))))
            (incf left-error (square (if (null weights)
                                         #2=(- value left-avg)
                                         (* (aref weights i) #2#)))))
        (finally (return (values (if (zerop left-count)
                                     0.0d0
                                     (/ left-error left-count))
                                 (if (zerop right-count)
                                     0.0d0
                                     (/ right-error right-count)))))))))


(defmethod calculate-score ((training-parameters regression)
                            split-array
                            training-state)
  (declare (optimize (speed 3) (safety 0))
           (type (simple-array boolean (*)) split-array))
  (regression-score split-array
                    (sl.tp:target-data training-state)
                    (sl.tp:weights training-state)))


(defmethod calculate-score ((training-parameters gradient-boost-classification)
                            split-array
                            training-state)
  (declare (optimize (speed 3) (safety 0))
           (type (simple-array boolean (*)) split-array))
  (~>> training-state
       sl.tp:target-data
       (regression-score split-array)))
