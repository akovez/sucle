(in-package #:window)

;;load order for the glfw3 binary:
;;1. Local filesystem
;;2. Fetch glfw-blob from asdf
;;3. Fetch glfw-blob from quicklisp, if quicklisp exists
;;4. Throw an error
;;;;Load the glfw3 library
(defparameter *glfw-library-loaded* nil)
(defun load-the-glfw-library ()
  (unless *glfw-library-loaded*
    (flet ((pexit (type)
	     (setf *glfw-library-loaded* type)
	     (return-from load-the-glfw-library t)))
      (or
       (block try-load-local
	 ;;this section ripped from cl-glfw3
	 (cffi:define-foreign-library (glfw)
	   (:darwin (:or
		     ;; homebrew naming
		     "libglfw3.1.dylib" "libglfw3.dylib"
		     ;; cmake build naming
		     "libglfw.3.1.dylib" "libglfw.3.dylib"))
	   (:unix (:or "libglfw.so.3.1" "libglfw.so.3"))
	   (:windows "glfw3.dll")
	   (t (:or (:default "libglfw3") (:default "libglfw"))))
	 
	 (handler-case (progn (cffi:use-foreign-library glfw)
			      (pexit "Local"))
	   (cffi:load-foreign-library-error (c)
	     ;;the library does not exist
	     (declare (ignorable c))
	     (return-from try-load-local nil))))
       
       #+(and
	  (or darwin linux windows)
	  (or x86 x86-64))
       (block try-load-glfw-blob
	 (cond
	   ;;try finding it in asdf
	   ((asdf:find-system :glfw-blob nil)
	    (asdf:load-system :glfw-blob)
	    (values (pexit "glfw-blob through asdf")))
	   #+quicklisp
	   (t
	    (ql:quickload :glfw-blob)
	    (values (pexit "glfw-blob through quicklisp")))
	   (t nil)))

       (error "no suitable library found for glfw!!!!")))))


;;;;************************************************************************;;;;
;;;;<ENUM>
;;;glfw enums to positions
(eval-always
  (defparameter *modified-mouse-enums*
  (quote
   ((:1 11) ;;0
    (:2 12) ;;1
    (:3 14) ;;2
    (:4 15);3
    (:5 16);4
    (:6 33);5
    (:7 34);6
    (:8 35);7
    (:last 35);8
    (:left 11);9
    (:right 12);;10
    )))

(defparameter *modified-key-enums*
  (quote
   (;;(:unknown -1)
    (:left-shift 0) ;;340 ----
    (:left-control 1);;341---
    (:left-alt 2);;342---
    (:left-super 3);;343--
    (:right-shift 4) ;;344 ----
    (:right-control 5);;345----
    (:right-alt 6);;;346---
    (:right-super 7);;347---
    (:backspace 8) ;;259***
    (:tab 9) ;;258***

    (:enter 10) ;;;257***
    11
    12
    (:kp-enter 13) ;;335***
    14
    15
    16   
    (:kp-0 17);;320----
    (:kp-1 18);;321----
    (:kp-2 19);;322----
    (:kp-3 20);;323----
    (:kp-4 21);;324----
    (:kp-5 22);;325----
    (:kp-6 23);;326----
    (:kp-7 24);;327----
    (:kp-8 25);;328----
    (:kp-9 26);;329----
    (:escape 27) ;;256***   
    (:up 28);;265---
    (:down 29) ;;264---
    (:right 30) ;;;262---
    (:left 31);;263---
    (:space 32)
    33
    34
    35
    (:menu 36) ;;348---
    (:kp-decimal 37);;330--
    (:kp-equal 38);;336--
    (:apostrophe 39)
    (:kp-divide 40);;;331---
    (:kp-subtract 41);;;333---
    (:kp-multiply 42);;332---
    (:kp-add 43);;;334---
    (:comma 44)
    (:minus 45)
    (:period 46)
    (:slash 47)
    (:0 48)
    (:1 49)
    (:2 50)
    (:3 51)
    (:4 52)
    (:5 53)
    (:6 54)
    (:7 55)
    (:8 56)
    (:9 57)
    (:insert 58);;260---
    (:semicolon 59)
    (:page-up 60);;266--
    (:equal 61)
    (:page-down 62);;267--
    
    (:pause 63);;284---
    (:print-screen 64);;;283---

    (:a 65)
    (:b 66)
    (:c 67)
    (:d 68)
    (:e 69)
    (:f 70)
    (:g 71)
    (:h 72)
    (:i 73)
    (:j 74)
    (:k 75)
    (:l 76)
    (:m 77)
    (:n 78)
    (:o 79)
    (:p 80)
    (:q 81)
    (:r 82)
    (:s 83)
    (:t 84)
    (:u 85)
    (:v 86)
    (:w 87)
    (:x 88)
    (:y 89)
    (:z 90)
    (:left-bracket 91)
    (:backslash 92)
    (:right-bracket 93)
    (:world-1 94);;161---
    (:world-2 95);;;162--- 
    (:grave-accent 96)
    (:f1 97);;290--
    (:f2 98);;291
    (:f3 99);;292
    (:f4 100);;;
    (:f5 101);;;
    (:f6 102);;;
    (:f7 103);;;
    (:f8 104);;
    (:f9 105);;;
    (:f10 106);;;;
    (:f11 107);;;
    (:f12 108);;;
    (:f13 109);;;
    (:f14 110);;;;
    (:f15 111);;;
    (:f16 112);;;
    (:f17 113);;;
    (:f18 114);;;
    (:f19 115);;;
    (:f20 116);;;;
    (:f21 117);;;;
    (:f22 118);;;
    (:f23 119);;;;
    (:f24 120);;;;
    (:f25 121);;;
    (:end 122);;;269---
    (:caps-lock 123);;280---
    (:scroll-lock 124);;;281---
    (:num-lock 125);;;282---
    (:home 126);;;268****
    (:delete 127) ;;261****
    )))
(defun to-claw (prefix sym &key (errorp t))
  (let ((string (concatenate 'string "+" prefix "-"(symbol-name sym) "+")))
    (multiple-value-bind (sym existsp)
	(find-symbol
	 string
	 (find-package "%GLFW"))
      (if existsp
	  (values sym t)
	  (if errorp
	      (error "~a not found in %GLFW package" string)
	      (values nil nil))))))
(defun substitute-foreign-enum-value (type name)
  (symbol-value (to-claw type name)))
(defparameter *mouse-array*
  (let ((array (make-array 8 :element-type '(unsigned-byte 8))))
    (dolist (x *modified-mouse-enums*)
      (when (listp x)
	(setf (aref array
		    (substitute-foreign-enum-value "MOUSE-BUTTON" (first x)))
	      (second x))))
    array))
(defparameter *key-array*
  (let ((array (make-array 349 :element-type '(unsigned-byte 8))))
    (dolist (x *modified-key-enums*)
      (when (listp x)
	(setf (aref array
		    (substitute-foreign-enum-value "KEY" (first x)))
	      (second x))))
    array))
(defparameter *character-keys*
  (let ((array (make-array 128 :element-type 'bit :initial-element 0)))
    (dotimes (i 97)
      (unless (zerop (aref *key-array* i))
	(setf (sbit array i) 1)))
    array))
;;escape, delete, backspace, tab, return/enter? are ascii?
(defparameter *back-map* 
  (let ((back-map (make-array 128)))
    (dolist (item *modified-mouse-enums*)
      (when (listp item)
	(setf (aref back-map (second item))
	      (cons :mouse (first item)))))
    (dolist (item *modified-key-enums*)
      (when (listp item)
	(setf (aref back-map (second item))
	      (cons :key (first item)))))
    back-map)))

(defun back-value (n)
  (let ((cell (aref *back-map* n)))
    (values (cdr cell)
	    (case (car cell)
	      (:key
	       :key)
	      (:mouse
	       :mouse)))))

;;Cache the translation from lisp object to key enum.
;;This saves time from symbol mangling.
;;Also mouseval and keyval were macros before, but why?
(defparameter *mouse-enum-cache* (make-hash-table :test 'eql))
(defparameter *key-enum-cache* (make-hash-table :test 'eql))
(defun mouseval (identifier)
  (multiple-value-bind (item existp) (gethash identifier *mouse-enum-cache*)
    (cond (existp item)
	  (t
	   (let ((new
		  (etypecase identifier
		    (keyword
		     (aref *mouse-array*
			   (substitute-foreign-enum-value "MOUSE-BUTTON" identifier)))
		    (integer
		     (aref *mouse-array* (1- identifier))))))
	     (setf (gethash identifier *mouse-enum-cache*) new)
	     new)))))
(defun keyval (identifier)
  (multiple-value-bind (item existp) (gethash identifier *key-enum-cache*)
    (cond (existp item)
	  (t
	   (let ((new
		  (etypecase identifier
		    (keyword
		     (aref *key-array*
			   (substitute-foreign-enum-value "KEY" identifier)))
		    (character
		     (char-code (char-upcase identifier)))
		    (integer
		     (char-code (digit-char identifier))))))
	     (setf (gethash identifier *key-enum-cache*) new)
	     new)))))

(defconstant +shift+ 1)
(defconstant +control+ 2)
(defconstant +alt+ 4)
(defconstant +super+ 8)
;;;;</ENUM>
;;;;************************************************************************;;;;


(defparameter *scroll-x* 0)
(defparameter *scroll-y* 0)
(defparameter *mouse-x* 0.0d0)
(defparameter *mouse-y* 0.0d0)
(defparameter *width* nil)
(defparameter *height* nil)
(defparameter *mod-keys* 0)

;;;; ## Float trap masking for OS X

;; Floating points traps need to be masked around certain
;; foreign calls on sbcl/darwin. Some private part of Cocoa
;; (Apple's GUI Framework) generates a SIGFPE that
;; invokes SBCLs signal handler if they're not masked.
;;
;; Traps also need to be restored during lisp callback execution
;; because SBCL relies on them to check division by zero, etc.
;; This logic is encapsulated in DEFINE-GLFW-CALLBACK.
;;
;; It might become necessary to do this for other implementations, too.

(defparameter *saved-lisp-fpu-modes* :unset)

(defmacro with-float-traps-saved-and-masked (&body body)
  "Turn off floating point traps and stash them
during execution of the given BODY. Expands into a PROGN if
this is not required for the current implementation."
  #+(and sbcl darwin)
    `(let ((*saved-lisp-fpu-modes* (sb-int:get-floating-point-modes)))
       (sb-int:with-float-traps-masked (:inexact :invalid
                                        :divide-by-zero :overflow
                                        :underflow)
         ,@body))
  #-(and sbcl darwin)
    `(progn ,@body))

(defmacro with-float-traps-restored (&body body)
  "Temporarily restore the saved float traps during execution
of the given BODY. Expands into a PROGN if this is not required
for the current implementation."
  #+(and sbcl darwin)
      (with-gensyms (modes)
        `(let ((,modes (sb-int:get-floating-point-modes)))
           (unwind-protect
                (progn
                  (when (not (eq *saved-lisp-fpu-modes* :unset))
                    (apply #'sb-int:set-floating-point-modes
                           *saved-lisp-fpu-modes*))
                  ,@body)
             (apply #'sb-int:set-floating-point-modes ,modes))))
  #-(and sbcl darwin)
  `(progn ,@body))

;;;
(glfw:define-key-callback key-callback (window key scancode action mod-keys)
  (declare (ignorable window scancode))
  (with-float-traps-restored
    (setf *mod-keys* mod-keys)
    (unless (= key -1)
      (let ((location (aref (etouq *key-array*) key)))
	(when (= action 2)
	  (setf (sbit *repeat-state* location) 1))
	(setf (sbit *input-state*
		    location)
	      (if (zerop action)
		  0
		  1))))))

(glfw:define-mouse-button-callback mouse-callback (window button action mod-keys)
  (declare (ignorable window))
  (with-float-traps-restored
    (setf *mod-keys* mod-keys)
    (setf (sbit *input-state*
		(aref (etouq *mouse-array*) button))
	  (if (zerop action)
	      0
	      1))))
;;;

#+nil
(glfw:define-char-callback char-callback (window char)
  (declare (ignorable window))
  (with-float-traps-restored
    (push char *char-keys*))
  )

(defmacro define-char-mods-callback (name (window codepoint mod-keys) &body body)
  `(cffi:defcallback ,name :void ((,window (:pointer ;;%glfw::window
					    ))
                                  (,codepoint :unsigned-int)
				  (,mod-keys :int))
     ,@body))
;;;[FIXME]move to bodge-glfw?
(define-char-mods-callback char-mods-callback (window char mod-keys)
  (declare (ignorable window))
  (setf *mod-keys* mod-keys)
  (with-float-traps-restored
    (push (list char mod-keys) *char-keys*))
  )
;;;;;;
(defmacro define-drop-callback (name (window count paths) &body body)
  `(cffi:defcallback ,name :void ((,window (:pointer;; %glfw::window
					    ))
                                  (,count :int)
				  (,paths (:pointer (:pointer :char))))
     ,@body))
;;;[FIXME]move to bodge-glfw?
(define-drop-callback drop-callback (window count paths)
  (declare (ignorable window))
  (with-float-traps-restored
    (dotimes (index count)
      (push
       (cffi:foreign-string-to-lisp (cffi:mem-aref paths :pointer index))
       *dropped-files*))))
;;;
(glfw:define-cursor-pos-callback cursor-callback (window x y)
  (declare (ignorable window))
  (with-float-traps-restored
    (setf *mouse-x* x)
    (setf *mouse-y* y)))
;;;
(glfw:define-scroll-callback scroll-callback (window x y)
  (declare (ignore window))
  (with-float-traps-restored
    (incf *scroll-x* x)
    (incf *scroll-y* y)))
;;;
(defparameter *resize-hook* (constantly nil))
(glfw:define-framebuffer-size-callback update-viewport (window w h)
  (declare (ignorable window))
  (with-float-traps-restored
    (setf *width* w *height* h)
    (funcall *resize-hook* w h)))

(defparameter *status* nil)
(defun init ()
  (reset-control-state *control-state*)
  (setf *scroll-x* 0.0
	*scroll-y* 0.0)
  (setq *status* nil)
  #+sbcl (sb-int:set-floating-point-modes :traps nil))

(defun poll-events ()
  (%glfw::poll-events))
(defparameter *shift* nil)
(defparameter *control* nil)
(defparameter *alt* nil)
(defparameter *super* nil)
(defparameter *char-keys* ())
(defparameter *dropped-files* ())
(defun poll ()
  #+nil
  (when *char-keys*
    (print *char-keys*))
  (setf *char-keys* nil)
  #+nil
  (when *dropped-files*
    (print *dropped-files*))
  (setf *dropped-files* nil)
  (setq *status* (let ((value (%glfw::window-should-close *window*)))
		   (cond ((eql value %glfw::+true+) t)
			 ((eql value %glfw::+false+) nil)
			 (t (error "what is this value? ~a" value)))))
  (poll-events)
  ;;;[FIXME]mod keys only updated indirectly through mouse or key or unicode char callback
  (let ((mods *mod-keys*))
    (setf *shift* (logtest +shift+ mods)
	  *control* (logtest +control+ mods)
	  *alt* (logtest +alt+ mods)
	  *super* (logtest +super+ mods))))


(defparameter *defaults*  
  '(:title "window"
    :width 1
    :height 1
    :resizable nil))

(defmacro with-window (window-keys &body body)
  (alexandria:with-gensyms (window extra)
    (alexandria:once-only (window-keys)
      `(let* ((,extra (append ,window-keys *defaults*))
	      (,window
	       (%glfw::create-window
		(getf 
		 ,extra
		 :width)
		(getf 
		 ,extra
		 :height)
		(getf 
		 ,extra
		 :title)
		(getf 
		 ,extra
		 :monitor)
		(getf 
		 ,extra
		 :shared))))
	 (unwind-protect
	      (progn
		(let ((*window* ,window))
		  (%glfw::make-context-current ,window)
		  ,@body))
	   (%glfw::destroy-window ,window))))))

(defparameter *window* nil)
;;Graphics calls on OS X must occur in the main thread
(defun set-callbacks (&optional (window *window*))
  (%glfw::set-mouse-button-callback window
				   (cffi:get-callback 'mouse-callback))
  (%glfw::set-key-callback window (cffi:get-callback 'key-callback))
  (%glfw::set-scroll-callback window (cffi:get-callback 'scroll-callback))
  (%glfw::set-window-size-callback window (cffi:get-callback 'update-viewport))
  ;;(%glfw::set-char-callback window (cffi:get-callback 'char-callback))
  (%glfw::set-char-mods-callback window (cffi:get-callback 'char-mods-callback)) 
  (%glfw::set-cursor-pos-callback window (cffi:get-callback 'cursor-callback))
  (%glfw::set-drop-callback window (cffi:get-callback 'drop-callback))
  )
(defmacro wrapper (args &body body)
  (alexandria:once-only (args)
    `(with-float-traps-saved-and-masked
       (load-the-glfw-library)
       (glfw:with-init ()
	 (init)
	 (glfw:with-window-hints
	     ;;[FIXME]better interface?
	     ((%glfw::+resizable+ (if (getf ,args :resizable)
				     %glfw::+true+
				     %glfw::+false+)))
	   (with-window ,args
	     (set-callbacks)
	     (setf (values *width*
			   *height*)
		   (get-window-size))
	     ,@body))))))

(defun get-mouse-out ()
  (%glfw::set-input-mode *window*  %glfw::+cursor+ %glfw::+cursor-normal+))

(defun toggle-mouse-capture ()
  (if (mouse-locked?)
      (%glfw::set-input-mode *window* %glfw::+cursor+ %glfw::+cursor-normal+)
      (%glfw::set-input-mode *window* %glfw::+cursor+ %glfw::+cursor-disabled+) ))

(defun mouse-locked? ()
  (eq %glfw::+cursor-disabled+
      (%glfw::get-input-mode *window* %glfw::+cursor+)))

(defun mouse-free? ()
  (eq  %glfw::+cursor-normal+
      (%glfw::get-input-mode *window* %glfw::+cursor+)))

(defun push-dimensions (width height)
  (setf *width* width
	*height* height)
  (%glfw::set-window-size *window* width height))

(defun set-caption (caption)
  (%glfw::set-window-title *window* caption))

(defun update-display ()
  (%glfw::swap-buffers *window*))

(defun set-vsync (bool)
  (if bool
      (%glfw::swap-interval 1) ;;1 is on
      (%glfw::swap-interval 0))) ;;0 is off

(defun get-window-size (&optional (window *window*))
  (cffi:with-foreign-objects ((w :int)
			      (h :int))
    (%glfw::get-window-size window w h)
    (values (cffi:mem-ref w :int)
	    (cffi:mem-ref h :int))))

(defun get-mouse-position (&optional (window *window*)) 
  (cffi:with-foreign-objects ((x :double) (y :double))
    (%glfw::get-cursor-pos window x y)
    (values 
     (cffi:mem-ref x :double)
     (cffi:mem-ref y :double))))
