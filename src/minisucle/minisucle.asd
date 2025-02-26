(asdf:defsystem #:minisucle
  :author "terminal625"
  :license "MIT"
  :description "Cube Demo Game"
  :depends-on
  (#:sucle-base
   #:alexandria  
   #:utility

   #:sucle-base
   #:aabbcc ;;for occlusion culling 
   #:livesupport)
  :serial t
  :components 
  ((:file "package")
   
   (:file "downgrade-array")
   (:file "voxel-chunks")
   
   (:file "util")
   (:file "menu")
   (:file "menus")
   (:file "physics")
   
   (:file "render")
   (:file "render-chunks")

   (:file "fix")
   (:file "mouse")
   (:file "modes")
   (:module "extra"
	    :serial t
	    :components
	    ((:file "render-extra")
	     ;;(:file "test")
	     ))
   
   (:file "sucle")))
