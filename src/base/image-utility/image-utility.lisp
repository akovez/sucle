(defpackage #:img
  (:use #:cl)
  (:shadow #:load)
  (:export
   #:w
   #:h
   #:load))

(in-package #:img)

(defparameter *flip-image-p* nil)
(defparameter *normalize-to-rgba-unsigned-byte-8* t)
(defun load (path &key (flip *flip-image-p*)
		    (normalize-to-rgba-unsigned-byte-8
		     *normalize-to-rgba-unsigned-byte-8*))
  "Return an image loaded from `path`. When `flip` is t, flip the rows of the image from top to bottom. Default is nil. If `normalize-to-rgba-unsigned-byte-8` is t, coerce the array, which may have various formats, such as black and white, rgb, or be of type 1,2,4,8,16,32 ubyte, to an array with depth 4 and type unsigned-byte 8. This conversion makes some assumptions. Default is t."
  (let ((array (opticl:read-image-file path)))
    (when flip
      (setf array (%flip-image array)))
    (when normalize-to-rgba-unsigned-byte-8
      (setf array (normalize-to-rgba-undigned-byte-8 array)))
    array))

;;[FIXME]image-width and image-height create garbage with cons cells?
(defun w (image)
  "Return the width of the image."
  (array-dimension image 0))
(defun h (image)
  "Return the height of the image."
  (array-dimension image 1))

(defun %flip-image (image)
  "Destructively flip the image in place."
  (let ((dims (array-dimensions image)))
    (let ((height (pop dims))
	  (longjumps (reduce #'* dims)))
      (declare (type fixnum height longjumps))
      (let ((magic (* longjumps (- height 1))))
	(loop for h below (* longjumps (- height (floor height 2))) by longjumps do
	     (loop for w below longjumps do
		  (rotatef (row-major-aref image (+ (- magic h) w))
			   (row-major-aref image (+ h w))))))))
  image)

(defun normalize-to-rgba-undigned-byte-8 (opticl-data)
  "Coerce the `opticl-data`, which may have various formats, such as black and white, rgb, or be of 1,2,4,8,16,32 ubyte, to an array with depth 4 and type unsigned-byte 8. This conversion makes some assumptions. Default is t."
  (let ((dimensions (array-dimensions opticl-data))
	(type (array-element-type opticl-data)))
    (when (or (not (eq 'unsigned-byte
		       (first type)))
	      (member type '(single-float double-float fixnum)))
      (error "type not supported"))
    (let ((channels (or (third dimensions)
			1))
	  (width (first dimensions))
	  (height (second dimensions)))
      (if (and (equal type '(unsigned-byte 8))
	       (= channels 4))
	  ;;Its in the rgba unsigned-byte 8 format, so just exit without converting
	  opticl-data
	  (let ((new (make-array (list width height 4)
				 :element-type '(unsigned-byte 8))))
	    ;;[FIXME]bits not correct? 
	    ;;32 -> 8 = ash n -24
	    ;;16 -> 8 = ash n -8
	    ;;8 -> 8 = identity n
	    ;;4 -> 8 = 15 -> 255 = * n 255/15 = * n 17
	    ;;2 -> 8 = 3 -> 255 = * n 85
	    ;;1 -> 8 = 1 -> 255 = * n 255
	    (flet ((u32->8 (n)
		     (declare (optimize (speed 3) (safety 0)))
		     (declare (type (unsigned-byte 32) n))
		     (ash n -24))
		   (u16->8 (n)
		     (declare (optimize (speed 3) (safety 0)))
		     (declare (type (unsigned-byte 16) n))
		     (ash n -8))
		   (u8->8 (n)
		     n)
		   (u4->8 (n)
		     (declare (optimize (speed 3) (safety 0)))
		     (declare (type (unsigned-byte 4) n))
		     (* n 17))
		   (u2->8 (n)
		     (declare (optimize (speed 3) (safety 0)))
		     (declare (type (unsigned-byte 2) n))
		     (* n 85))
		   (u1->8 (n)
		     (declare (optimize (speed 3) (safety 0)))
		     (declare (type (unsigned-byte 1) n))
		     (* n 255)))
	      (let ((convert-fun (ecase (second type)
				   (32 #'u32->8)
				   (16 #'u16->8)
				   (8 #'u8->8)
				   (4 #'u4->8)
				   (2 #'u2->8)
				   (1 #'u1->8))))
		(flet ((convert-value (value)
			 (funcall convert-fun value)))
		  (flet ((dump-pixels-1 (w h)
			   (let ((gray
				  (convert-value (aref opticl-data w h))))
			     ;;[FIXME]include alpha channel or not?
			     (values
			      gray
			      gray
			      gray
			      255)))
			 (dump-pixels-2 (w h)
			   (let ((gray (convert-value (aref opticl-data w h 0)))
				 (alpha (convert-value (aref opticl-data w h 1))))
			     (values gray gray gray alpha)))
			 (dump-pixels-3 (w h)
			   (values
			    (convert-value (aref opticl-data w h 0))
			    (convert-value (aref opticl-data w h 1))
			    (convert-value (aref opticl-data w h 2))
			    255))
			 (dump-pixels-4 (w h)
			   (values
			    (convert-value (aref opticl-data w h 0))
			    (convert-value (aref opticl-data w h 1))
			    (convert-value (aref opticl-data w h 2))
			    (convert-value (aref opticl-data w h 3)))))
		    (let ((dump-pixels-fun (ecase channels
					     (1 #'dump-pixels-1)
					     (2 #'dump-pixels-2)
					     (3 #'dump-pixels-3)
					     (4 #'dump-pixels-4))))
		      (dotimes (w width)
			(dotimes (h height)
			  (multiple-value-bind (r g b a) (funcall dump-pixels-fun w h)
			    (let ((base (* 4 (+ h (* height w)))))
			      (setf (row-major-aref new (+ base 0)) r
				    (row-major-aref new (+ base 1)) g
				    (row-major-aref new (+ base 2)) b
				    (row-major-aref new (+ base 3)) a))))))))))
	    new)))))

;;a -> a a a 1.0 or a a a a?
;;ra -> r r r a
;;rgb -> r g b 1.0
;;rgba -> r g b a
