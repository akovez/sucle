(asdf:defsystem #:uncommon-lisp
  :author "terminal625"
  :license "MIT"
  :description "Trivially convert from a struct form to an equivalent defclass"
  :depends-on (#:structy-defclass)
  :components 
  ((:file "struct-to-clos")))
