(cl:in-package #:statistical-learning.tree-protocol)


(defgeneric root (model))
(defgeneric treep (node))
(defgeneric leafp (node))
(defgeneric maximal-depth (training-parameters))
(defgeneric depth (state))
(defgeneric (setf depth) (new-value state))
(defgeneric training-parameters (state))
(defgeneric (setf training-parameters) (new-value state))
(defgeneric make-node (node-class &rest arguments))
(defgeneric trials-count (training-parameters))
(defgeneric force-tree* (tree))
(defgeneric left-node (tree))
(defgeneric (setf left-node) (new-value tree))
(defgeneric right-node (tree))
(defgeneric (setf right-node) (new-value tree))
(defgeneric minimal-size (training-parameters))
(defgeneric attribute (tree-node))
(defgeneric (setf attribute) (new-value tree-node))
(defgeneric target-data (training-state))
(defgeneric (setf target-data) (new-value training-state))
(defgeneric parallel (training-parameters))
(defgeneric split* (training-parameters training-state leaf))
(defgeneric attribute-value (tree-node))
(defgeneric (setf attribute-value) (new-value tree-node))
(defgeneric attribute-indexes (training-state))
(defgeneric (setf attribute-indexes) (new-value training-state))
(defgeneric make-leaf* (training-parameters training-state))
(defgeneric initialize-leaf (training-parameters training-state leaf))
(defgeneric make-training-state (parameters train-data target-data
                                 &rest initargs &key &allow-other-keys))
(defgeneric split-training-state* (parameters state split-array
                                   position size initargs
                                   &optional attribute-index attribute-indexes))
(defgeneric sample-training-state* (parameters state
                                    &key
                                      data-points
                                      train-attributes
                                      target-attributes
                                      initargs
                                    &allow-other-keys))
(defgeneric loss (state))
(defgeneric (setf loss) (new-value state))
(defgeneric calculate-loss* (parameters state split-array))
(defgeneric contribute-predictions* (parameters model data state parallel))
(defgeneric extract-predictions* (parameters state))
(defgeneric weights (state))
(defgeneric (setf weights) (new-value state))
(defgeneric support (node))
(defgeneric (setf support) (new-value node))
(defgeneric predictions (node))
(defgeneric (setf predictions) (new-value node))
(defgeneric sums (predictions))
(defgeneric indexes (predictions))
(defgeneric contributions-count (predictions))
(defgeneric training-parameters (predictions))
