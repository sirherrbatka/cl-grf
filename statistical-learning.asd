(cl:in-package #:cl-user)


(asdf:defsystem statistical-learning
  :name "cl-grf"
  :version "0.0.0"
  :license "BSD simplified"
  :author "Marek Kochanowicz"
  :depends-on ( :iterate       :serapeum
                :lparallel     :cl-data-structures
                :metabang-bind :alexandria
                :documentation-utils-extensions)
  :serial T
  :pathname "source"
  :components ((:file "aux-package")
               (:module "data"
                :components ((:file "package")
                             (:file "macros")
                             (:file "types")
                             (:file "functions")
                             (:file "extras")))
               (:module "random"
                :components ((:file "package")
                             (:file "discrete-distribution")))
               (:module "model-protocol"
                :components ((:file "package")
                             (:file "generics")
                             (:file "types")
                             (:file "functions")
                             (:file "methods")
                             (:file "documentation")))
               (:module "optimization"
                :components ((:file "package")
                             (:file "generics")
                             (:file "types")
                             (:file "variables")
                             (:file "utils")
                             (:file "methods")
                             (:file "functions")
                             ))
               (:module "performance"
                :components ((:file "package")
                             (:file "generics")
                             (:file "types")
                             (:file "methods")
                             (:file "utils")
                             (:file "functions")
                             (:file "documentation")
                             ))
               (:module "tree-protocol"
                :components ((:file "package")
                             (:file "macros")
                             (:file "generics")
                             (:file "types")
                             (:file "variables")
                             (:file "utils")
                             (:file "functions")
                             (:file "methods")
                             ))
               (:module "proxy-tree"
                :components ((:file "package")
                             (:file "generics")
                             (:file "macros")
                             (:file "types")
                             (:file "utils")
                             (:file "functions")
                             (:file "methods")
                             (:file "honest-tree")
                             (:file "causal-tree")
                             (:file "indexing-tree")
                             ))
               (:module "decision-tree"
                :components ((:file "package")
                             (:file "generics")
                             (:file "types")
                             (:file "utils")
                             (:file "functions")
                             (:file "methods")
                             ))
               (:module "gradient-boost-tree"
                :components ((:file "package")
                             (:file "generics")
                             (:file "types")
                             (:file "utils")
                             (:file "methods")
                             ))
               (:module "ensemble"
                :components ((:file "package")
                             (:file "generics")
                             (:file "types")
                             (:file "utils")
                             (:file "functions")
                             (:file "methods")))))
