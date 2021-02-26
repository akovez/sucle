(asdf:defsystem #:window
  :author "terminal625"
  :license "MIT"
  :description "glfw3 opengl context creation, windowing and input"
 
  :depends-on (#:bodge-glfw
	       #:cffi
	       #:trivial-features
	       #:utility
	       #:alexandria)
  :serial t
  :components  
  ((:file "package")
   (:file "glfw3")
   (:file "input-array"))) 
