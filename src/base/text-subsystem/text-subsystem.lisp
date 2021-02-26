(defpackage #:text-sub
  (:use #:cl
	#:application)
  (:import-from
   #:utility
   #:etouq
   #:dobox
   #:with-gensyms
   #:once-only
   #:floatify
   #:with-unsafe-speed)
  (:export
   #:*block-width*
   #:*block-height*
   #:*text-data-what-type*
   #:change-color-lookup
   #:*text-data-width*
   #:*text-data-height*
   #:char-attribute

   #:with-text-shader
   #:draw-fullscreen-quad

   #:text-data
   #:indirection
   #:font-texture

   #:text-shader
   #:use-text-shader
   #:submit-text-data))
(in-package #:text-sub)

(defparameter *text-data-what-type*
  ;;:framebuffer
  :texture-2d
  )

(defun make-texture-or-framebuffer (type w h)
  (ecase type
    (:framebuffer
     (glhelp:make-gl-framebuffer w h))
    (:texture-2d
     (glhelp:wrap-opengl-texture
      (glhelp:create-texture nil w h)))))
;;[FIXME] 256 by 256 size limit for texture
(defparameter *text-data-height* 256)
(defparameter *text-data-width* 256)
(defun make-text-data ()
  (make-texture-or-framebuffer
  *text-data-what-type* *text-data-width* *text-data-height*))
(glhelp:deflazy-gl text-data () (make-text-data))

(glhelp:deflazy-gl
 font-texture ()
 (let ((font-png
	(let ((array
	       (img:load
		(sucle-temp:path "res/font.png"))))
	  (dobox ((width 0 (img:w array))
		  (height 0 (img:h array)))
		 (let ((value (aref array width height 0)))
		   (setf (aref array width height 3) 255)
		   (dotimes (i 3)
		     (setf (aref array width height i) value))))
	  array)))  
   (glhelp:wrap-opengl-texture (glhelp:create-opengl-texture-from-data font-png))))

;;Writing text to OpenGL via a framebuffer. disabled for now
;;Its highly optimized, but is it solving a necessary problem?
;;Disabled.
#+nil
(defparameter *trans* (sb-cga:scale* (/ 1.0 128.0) (/ 1.0 128.0) 1.0))
#+nil
(defun retrans (x y &optional (trans *trans*))
  (setf (aref trans 12) (/ x 128.0)
	(aref trans 13) (/ y 128.0))
  trans)
#+nil
(defmacro with-data-shader ((uniform-fun rebase-fun) &body body)
  (with-gensyms (program)
    `(let ((,program (deflazy:getfnc 'flat-shader)))
       (glhelp:use-gl-program ,program)
       (let ((framebuffer (deflazy:getfnc 'text-data)))
	 (gl:bind-framebuffer :framebuffer (glhelp:handle framebuffer))
	 (glhelp:set-render-area 0 0
				 ;;[FIXME] not use generic functions?
				 (glhelp:w framebuffer)
				 (glhelp:h framebuffer)
				 ))
       (glhelp:with-uniforms ,uniform-fun ,program
	 (flet ((,rebase-fun (x y)
		  (gl:uniform-matrix-4fv
		   (,uniform-fun :pmv)
		   (retrans x y)
		   nil)))
	   ,@body)))))

(defun char-attribute (bold-p underline-p opaque-p)
  (logior
   (if bold-p
       2
       0)
   (if underline-p
       1
       0)
   (if opaque-p
       4
       0)))

;;;;4 shades each of r g b a 0.0 1/3 2/3 and 1.0
(defun color-fun (color)
  (let ((one-third (etouq (coerce 1/3 'single-float))))
    (macrolet ((k (num)
		 `(* one-third (floatify (ldb (byte 2 ,num) color)))))
      (values (k 0)
	      (k 2)
	      (k 4)
	      (k 6)))))
(defun color-rgba (r g b a)
  (dpb a (byte 2 6)
       (dpb b (byte 2 4)
	    (dpb g (byte 2 2)
		 (dpb r (byte 2 0) 0)))))

(defmacro with-foreign-array ((var lisp-array type &optional (len (gensym)))
			      &rest body)
  (with-gensyms (i)
    (once-only (lisp-array)
      `(let ((,len (array-total-size ,lisp-array)))
	 (cffi:with-foreign-object (,var ,type ,len)
	   (dotimes (,i ,len)
	     (setf (cffi:mem-aref ,var ,type ,i)
		   (row-major-aref ,lisp-array ,i)))
	   ,@body)))))
(defparameter *16x16-tilemap* (rectangular-tilemap:regular-enumeration 16 16))

;;;each glyph gets a float which is a number that converts to 0 -> 255.
;;;this is an instruction that indexes into an "instruction set" thats the *attribute-bits*
#+nil
(defparameter *attribute-bits*
  (let ((array (make-array (* 4 256) :element-type 'single-float)))
    (flet ((logbitter (index integer)
	     (if (logtest index integer)
		 1.0
		 0.0)))
      (dotimes (base 256)
	(let ((offset (* base 4)))
	  (setf (aref array (+ offset 0)) (logbitter 1 offset)
		(aref array (+ offset 1)) (logbitter 2 offset)
		(aref array (+ offset 2)) (logbitter 4 offset)
		(aref array (+ offset 3)) (logbitter 8 offset)))))
    array))
(defparameter *terminal256color-lookup* (make-array (* 4 256) :element-type 'single-float))
;;;256 color - 128 fontdata - 16 bit decoder
(defparameter *color-font-info-data*
  (let ((array (make-array (* 4 (+ 256 ;;color
				   128 ;;font
				   16  ;;bit decoder
				   )) :element-type 'single-float)))
    (dotimes (i (* 4 128))
      (setf (aref array (+ i (* 4 256)))
	    (aref *16x16-tilemap* i)))
    (flet ((fun (n)
	     (if n
		 1.0
		 0.0)))
      (dotimes (i 16)
	(let ((offset (* 4 (+ 256
			      128
			      i))))
	  (setf (aref array (+ offset 0)) (fun (logtest 1 i)))
	  (setf (aref array (+ offset 1)) (fun (logtest 2 i)))
	  (setf (aref array (+ offset 2)) (fun (logtest 4 i)))
	  (setf (aref array (+ offset 3)) (fun (logtest 8 i))))))
    array))
(defun write-to-color-lookup (color-fun)
  (let ((arr *color-font-info-data*))
    (dotimes (x 256)
      (let ((offset (* 4 x)))
	(multiple-value-bind (r g b a) (funcall color-fun x) 
	  (setf (aref arr (+ offset 0)) r)
	  (setf (aref arr (+ offset 1)) g)
	  (setf (aref arr (+ offset 2)) b)
	  (setf (aref arr (+ offset 3)) (if a a 1.0)))))
    arr))
(write-to-color-lookup 'color-fun)
(defun change-color-lookup (color-fun)
  (deflazy:refresh 'text-shader)
  (write-to-color-lookup color-fun))
(glhelp:deflazy-gl
 text-shader
 () 
 (let ((shader (glhelp:create-gl-program2
		'(:vs
		  "
out vec2 texcoord_out;
in vec4 position;
in vec2 texcoord;
uniform mat4 projection_model_view;
void main () {
gl_Position = projection_model_view * position;
texcoord_out = texcoord;
}"
		  :frag
		  "
in vec2 texcoord_out;
uniform sampler2D indirection;
uniform sampler2D text_data;
uniform vec4[400] color_font_info_atlas;
uniform sampler2D font_texture;
void main () {
vec4 ind = texture2D(indirection, texcoord_out); //indirection
vec4 raw = texture2D(text_data, ind.ba);
ivec4 chardata = ivec4(255.0 * raw); //where the text changes go
//convert a 4-bit number to a vec4 of 1.0's and 0.0's
vec4 infodata = color_font_info_atlas[384 + chardata.a];
vec2 offset = vec2(0.5, 0.5) * infodata.xy;
float opacity = infodata.z;
//font atlass coordinates
vec4 font_data = color_font_info_atlas[256 + chardata.r]; 
//bug workaround?
vec4 pixcolor = texture2D(font_texture,offset+vec2(0.5,1.0)*mix(font_data.xy,font_data.zw,ind.rg));
vec4 fin = mix(color_font_info_atlas[chardata.g],color_font_info_atlas[chardata.b],pixcolor);
gl_FragColor.rgb = fin.rgb;
gl_FragColor.a = opacity * fin.a;
}"
		  :attributes
		  (("position" . 0) 
		   ("texcoord" . 2))
		  :uniforms
		  ((:pmv . "projection_model_view")
		   (indirection . "indirection")
		   ;;(attributedata (:fragment-shader attributeatlas))
		   (text-data . "text_data")
		   (color-font-info-data . "color_font_info_atlas")
		   (font-texture . "font_texture")))
		)))
   (glhelp:use-gl-program shader)
   (glhelp:with-uniforms uniform shader
      (with-foreign-array (var *color-font-info-data* :float len)
	(%gl:uniform-4fv (uniform 'color-font-info-data)
			 (/ len 4)
			 var))
      (with-foreign-array (var *color-font-info-data* :float len)
      (%gl:uniform-4fv (uniform 'color-font-info-data)
		       (/ len 4)
		       var)))
    shader))
#+nil
(glhelp:deflazy-gl flat-shader ()
  (glhelp:create-opengl-shader 
   "
out vec4 value_out;
in vec4 value;
in vec4 position;
uniform mat4 projection_model_view;

void main () {
gl_Position = projection_model_view * position;
value_out = value;
}"
   "
in vec4 value_out;
void main () {
gl_FragColor = value_out;
}"
   '(("position" 0) 
     ("value" 3))
   '((:pmv "projection_model_view"))))


;;;;;;;;;;;;;;;;;;;;
#+nil
(glhelp:deflazy-gl indirection-shader ()
  (glhelp:create-opengl-shader
   "
out vec2 texcoord_out;
in vec4 position;
in vec2 texcoord;
uniform mat4 projection_model_view;

void main () {
gl_Position = projection_model_view * position;
texcoord_out = texcoord;
}"
   "
in vec2 texcoord_out;
uniform vec2 size;

void main () {
//rg = fraction
//ba = text lookup

vec2 foo = floor(texcoord_out * size) / vec2(255.0);
vec2 bar = fract(texcoord_out * size);
vec4 pixcolor; //font lookup
pixcolor.rg = bar; //fraction
pixcolor.ba = foo; // text lookup

gl_FragColor = pixcolor; 
}"
   '(("position" 0) 
     ("texcoord" 2))
   '((:pmv "projection_model_view")
     (size "size"))))

(glhelp:deflazy-gl fullscreen-quad ()
  (let ((a (scratch-buffer:my-iterator))
	(b (scratch-buffer:my-iterator))
	(len 4))
    (scratch-buffer:bind-out* ((a pos)
			       (b tex))
      (etouq (cons 'pos (axis-aligned-quads:quadk+ 0.5 '(-1.0 1.0 -1.0 1.0))))
      (etouq
	(cons 'tex
	      (axis-aligned-quads:duaq 1 nil '(0.0 1.0 0.0 1.0)))))
    (scratch-buffer:flush-bind-in* ((a xyz)
				    (b tex))
      (glhelp:create-vao-or-display-list-from-specs
       (:quads len)
       ((2 (tex) (tex))
	(0 (xyz) (xyz) (xyz) 1.0))))))

(defun draw-fullscreen-quad ()
  (glhelp:slow-draw (deflazy:getfnc 'fullscreen-quad)))

;;;;;;;;;;;;;;;;
(defparameter *block-height* 16.0)
(defparameter *block-width* 8.0)
;;[FIXME]->use the new unchanged-feature in deflazy.
(deflazy:deflazy block-h ()
  *block-height*)
(deflazy:deflazy block-w ()
  *block-width*)
(defun block-dimension-change (&optional (w *block-width*) (h *block-height*))
  (unless (= (deflazy:getfnc 'block-h) h)
    (deflazy:refresh 'block-h t))
  (unless (= (deflazy:getfnc 'block-w) w)
    (deflazy:refresh 'block-w t)))

;;;;a framebuffer is faster and allows rendering to it if thats what you want
;;;;but a texture is easier to maintain. theres no -ext framebuffer madness,
;;;;no fullscreen quad, no shader. just an opengl texture and a char-grid
;;;;pattern to put in it.
(defparameter *indirection-what-type*
  ;;:framebuffer
  :texture-2d
  )
(glhelp:deflazy-gl indirection ((w application:w)
				(h application:h)
				block-w
				block-h
				;;FIXME::these are not necessarily used,
				;;but factor in. Be more like the
				;;kenny-tilton cells engine?
				;;indirection-shader
				;;fullscreen-quad
				)
		   ;;Careful dealing with deflazy and OpenGL.
		   ;;Opengl is necessarily stateful, whereas deflazy
		   ;;tries to be more functional. The clash
		   ;;of the two breaks the abstraction.
  (let* ((upw (power-of-2-ceiling w))
	 (uph (power-of-2-ceiling h))
	 #+nil
	 (need-to-update-size
	  (not (and (= *indirection-width* upw)
		    (= *indirection-height* uph)))))
    ;;[FIXME] The size of the indirection texture does not
    ;;need to be updated if the power of twos align.
    #+nil
    (when need-to-update-size
      (setf *indirection-width* upw
	    *indirection-height* uph)
      (deflazy:refresh 'indirection t))
    
    ;;;refresh the indirection
    (let ((indirection (make-texture-or-framebuffer *indirection-what-type* upw uph)))
      (etypecase indirection
	#+nil
	(glhelp:gl-framebuffer
	 (let ((refract indirection-shader))
	   (glhelp:use-gl-program refract)
	   (glhelp:with-uniforms uniform refract
	     (gl:uniform-matrix-4fv
	      (uniform :pmv)
	      (load-time-value (sb-cga:identity-matrix))
	      nil)
	     (gl:uniformf (uniform 'size)
			  (/ w block-w)
			  (/ h block-h))))
	 (gl:disable :cull-face)
	 (gl:disable :depth-test)
	 (gl:disable :blend)
	 (glhelp:set-render-area 0 0 upw uph)
	 (gl:bind-framebuffer :framebuffer (glhelp:handle indirection))
	 (gl:clear :color-buffer-bit)
	 (gl:clear :depth-buffer-bit)
	 (glhelp:slow-draw fullscreen-quad))
	(glhelp:gl-texture
	 (gl:bind-texture :texture-2d (glhelp:handle indirection))
	 (cffi:with-foreign-object (data :uint8 (* upw uph 4))
	   (let* (;;tempx and tempy
		  (uph2 (the fixnum (* 2 uph)))
		  (upw2 (the fixnum (* 2 upw)))
		  (tempx (* upw2 block-w))
		  (tempy (* uph2 block-h))
		  )
	     ;;[FIXME] nonportably declares things to be fixnums for speed
	     ;;The x and y components are independent of each other, so instead of
	     ;;computing x and y per point, compute once per x value or v value.
	     ;;[FIXME]Optmize?
	     (loop :for x :from 0 :below upw2 :by 2 :do
		(let* ((tex-x (* w (+ 1 x)))
		       (mod-tex-x-tempx (mod tex-x tempx))
		       (barx (foobar (* 255 mod-tex-x-tempx) tempx))
		       (foox (/ (- tex-x mod-tex-x-tempx) tempx))
		       (base (* 2 x))
		       (delta (* 2 upw2)))
		  (declare (type fixnum base)
			   (type (unsigned-byte 8) barx foox)
			   (optimize (speed 3) (safety 0)))
		  (loop :repeat (the fixnum uph) :do
		     ;;y
		     (setf (cffi:mem-ref data :uint8 (+ base 0)) barx
			   (cffi:mem-ref data :uint8 (+ base 2)) foox)
		     (setf base (the fixnum (+ base delta))))))
	     (loop :for y :from 0 :below uph2 :by 2 :do
		(let* ((tex-y (* h (+ 1 y)))
		       (mod-tex-y-tempy (mod tex-y tempy))
		       (bary (foobar (* 255 mod-tex-y-tempy) tempy))	
		       (fooy (/ (- tex-y mod-tex-y-tempy) tempy))
		       (base (* upw2 y)))
		  (declare (type fixnum base)
			   (type (unsigned-byte 8) bary fooy)
			   (optimize (speed 3) (safety 0)))		      
		  (loop :repeat (the fixnum upw) :do
		     ;;x
		     (setf (cffi:mem-ref data :uint8 (+ base 1)) bary
			   (cffi:mem-ref data :uint8 (+ base 3)) fooy)
		     (setf base (the fixnum (+ base 4)))))))
	   (gl:tex-image-2d :texture-2d 0 :rgba upw uph 0 :rgba :unsigned-byte data))))
      indirection)))
(defun foobar (x y)
  ;;(floor (/ x y)) <- equivalent
  (/ (- x (mod x y)) y)
  )
;;;Round up to next power of two
(defun power-of-2-ceiling (n)
  (ash 1 (ceiling (log n 2))))
;;;
(defun use-text-shader
    (&key
       (pmv (load-time-value (nsb-cga:identity-matrix))
	    ;;pmv-supplied-p
	    )
       (indirection (glhelp:texture-like
		     (deflazy:getfnc 'indirection))
		    ;;indirection-supplied-p
		    )
       (font-texture (glhelp:handle
		      (deflazy:getfnc 'font-texture))
		     ;;font-texture-supplied-p
		     )
       (text-data (glhelp:texture-like
		   (deflazy:getfnc 'text-data))
		  ;;text-data-supplied-p
		  ))
  (deflazy:getfnc 'indirection)
  (let ((program (deflazy:getfnc 'text-shader)))
    (glhelp:use-gl-program program)
    (glhelp:with-uniforms
     uniform-fun program
     (glhelp::set-uniform-to-texture
      (uniform-fun 'indirection)
      indirection
      0)
     (glhelp::set-uniform-to-texture
      (uniform-fun 'font-texture)
      font-texture
      1)
     (glhelp::set-uniform-to-texture
      (uniform-fun 'text-data)
      text-data
      2)
     (gl:uniform-matrix-4fv
      (uniform-fun :pmv)
      pmv
      nil))))
					;#+nil
#+nil
(defun text-subsystem ()

  ;;variables
  *text-data-what-type*
  *terminal256color-lookup*
  *block-height*
  *block-width*
  *indirection-what-type*
 
  ;;functions
  write-to-color-lookup
  change-color-lookup
  
  ;;macro
  with-text-shader
  with-data-shader
  
  ;;deflazy
  (let*
      ((text-data (deflazy:lazgen text-data))
       (text-shader (deflazy:lazgen text-shader text-shader-source2))
       (font-texture (deflazy:lazgen font-texture font-png))  ;;   
       
       (flat-shader (deflazy:lazgen flat-shader))
       (indirection (deflazy:lazgen indirection))
       (indirection-shader (deflazy:lazgen indirection-shader))
       (fullscreen-quad (deflazy:lazgen fullscreen-quad))))

  text-data
  font-texture
  color-lookup
  indirection
  )


#+nil
(symbol-macrolet ((foo (foo bar)))
  (macrolet ((yolo (form)
	       (with-output-to-string (str)
		 (print form str))))
    (yolo foo)))

(defun submit-text-data
    (arr c-array-columns c-array-lines
     &optional (texture (glhelp:texture-like (deflazy:getfnc 'text-sub:text-data))))
  (gl:bind-texture :texture-2d texture)
  (gl:tex-sub-image-2d :texture-2d 0 0 0
		       c-array-columns
		       c-array-lines
		       :rgba :unsigned-byte arr))

(struct-to-clos:struct->class
 (defstruct port
   text-data
   indirection
   x
   y
   w
   h
   sync))

(defun port (&optional (x 0) (y 0) (w 100) (h 100))
  (make-port :text-data (;;deflazy:lazgen
			    text-data
			    (deflazy:getfnc
				(deflazy:singleton 'glhelp:gl-context)))
	     :indirection (progn ;;deflazy:dlaz
			    (apply 'indirection w h *block-width* *block-height*
				   #+nil
				  (deflazy:getfnc
				      (deflazy:singleton 'indirection-shader))
				  #+nil
				  (deflazy:getfnc
				      (deflazy:singleton 'fullscreen-quad))
				  (deflazy:getfnc
				      (deflazy:singleton 'glhelp:gl-context))
				  ()))
	     :x x
	     :y y
	     :w w
	     :h h))

(defun destroy-port (port)
  (;;dependency-graph:annihilate
   glhelp::gl-delete*
   (port-text-data port))
  (;;dependency-graph:annihilate
   glhelp::gl-delete*
   (port-indirection port)))
(defmethod dependency-graph:cleanup-node-value ((obj port))
  (destroy-port obj))

(defun port-data (port)
  (glhelp:texture-like (progn ;;deflazy:getfnc
			   (port-text-data port))))
(defun %port-indirection (port)
  (glhelp:texture-like (progn ;;deflazy:getfnc
			   (port-indirection port))))

(defun draw-port (port)
  (let (;;indirection fulfilled before anything else
	;;because it has side effects in OpenGL
	(indirection (%port-indirection port)))
    (gl:polygon-mode :front-and-back :fill)
    (gl:disable :cull-face)
    (gl:disable :depth-test)
    (gl:disable :blend)
    (text-sub:use-text-shader :text-data
			      (port-data port)
			      :indirection
			      indirection))
  ;;[FIXME] unconfigurable? configuration good and bad
  (glhelp:bind-default-framebuffer)
  (glhelp:set-render-area
   (port-x port)
   (port-y port)
   (port-w port)
   (port-h port))
  #+nil
  (progn
    (gl:enable :blend)
    (gl:blend-func :src-alpha :one-minus-src-alpha))

  (text-sub:draw-fullscreen-quad))
