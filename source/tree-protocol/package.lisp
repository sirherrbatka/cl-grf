(cl:in-package #:cl-user)


(defpackage #:statistical-learning.tree-protocol
  (:use #:cl #:statistical-learning.aux-package)
  (:nicknames #:statistical-learning.tp #:sl.tp)
  (:intern sl.opt:left sl.opt:right)
  (:export
   #:attribute-indexes
   #:calculate-loss*
   #:calculate-loss*/proxy
   #:contribute-predictions
   #:contribute-predictions*
   #:contribute-predictions*/proxy
   #:contributed-predictions
   #:contributions-count
   #:depth
   #:distance-splitter
   #:extract-predictions
   #:extract-predictions*
   #:extract-predictions*/proxy
   #:fill-split-vector*
   #:fill-split-vector*/proxy
   #:force-tree
   #:force-tree*
   #:fundamental-leaf-node
   #:fundamental-node
   #:fundamental-splitter
   #:fundamental-tree-node
   #:fundamental-tree-training-parameters
   #:indexes
   #:initialize-leaf
   #:initialize-leaf/proxy
   #:leaf-for
   #:leaf-for/proxy
   #:leafp
   #:leafs-for
   #:left-node
   #:loss
   #:make-leaf
   #:make-leaf*
   #:make-leaf*/proxy
   #:make-node
   #:maximal-depth
   #:minimal-difference
   #:minimal-size
   #:parallel
   #:pick-split
   #:pick-split*
   #:pick-split*/proxy
   #:point
   #:predictions
   #:random-attribute-splitter
   #:requires-split-p
   #:requires-split-p/proxy
   #:right-node
   #:root
   #:split
   #:split*
   #:split*/proxy
   #:split-training-state
   #:split-training-state*
   #:split-training-state*/proxy
   #:split-training-state-info
   #:split-training-state-info/proxy
   #:splitter
   #:standard-leaf-node
   #:standard-tree-training-parameters
   #:sums
   #:support
   #:training-state-clone
   #:tree-model
   #:tree-training-state
   #:treep
   #:trials-count
   #:visit-nodes))
