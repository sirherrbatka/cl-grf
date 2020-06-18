(cl:in-package #:statistical-learning.model-protocol)


(defgeneric make-model* (parameters training-state))
(defgeneric predict (model data &optional parallel))
(defgeneric parameters (model))
(defgeneric make-training-state (parameters train-data target-data
                                 &rest initargs &key &allow-other-keys))
(defgeneric sample-training-state* (parameters state
                                    &key
                                      data-points
                                      train-attributes
                                      target-attributes
                                      initargs
                                    &allow-other-keys))
