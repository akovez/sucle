(in-package :sucle)

;;;;************************************************************************;;;;
;;;;<BOXES?>
(defun create-aabb (&optional (maxx 1.0) (maxy maxx) (maxz maxx)
			       (minx (- maxx)) (miny (- maxy)) (minz (- maxz)))
	 (floatf maxx maxy maxz minx miny minz)
	 (aabbcc:make-aabb
	  :minx minx
	  :maxx maxx
	  :miny miny
	  :maxy maxy
	  :minz minz
	  :maxz maxz))

(defparameter *player-aabb*
  (create-aabb 0.3 0.12 0.3 -0.3 -1.5 -0.3))

(defun start ()
  (app:enter 'sucle-app))

(defun sucle-app ()
  #+nil
  (setf (entity-fly? *ent*) nil
	(entity-gravity? *ent*) t)
  (window:set-vsync t)
  (fps:set-fps 60)
  (ncurses-clone-for-lem:init)
  (menu:use *start-menu2*)
  (app:push-mode 'menu:tick)

  (fix::fix)
  (fix::seed)

  ;;(sucle-mp:with-initialize-multiprocessing)
  (app:default-loop))


;;;;************************************************************************;;;;
;;;;This code basically has not changed in forever.

(defparameter *raw-mouse-x* 0.0d0)
(defparameter *raw-mouse-y* 0.0d0)
(defun cursor-motion-difference
    (&optional (x window:*mouse-x*) (y window:*mouse-y*))
  ;;Return the difference in position of the last time the
  ;;cursor was observed.
  ;;*raw-mouse-x* and *raw-mouse-y* hold the last value
  ;;of the cursor.
  (multiple-value-prog1
      (values (- x *raw-mouse-x*)
	      (- y *raw-mouse-y*))
    (setf *raw-mouse-x* x
	  *raw-mouse-y* y)))

(defparameter *mouse-x* 0.0d0)
(defparameter *mouse-y* 0.0d0)
(defparameter *lerp-mouse-x* 0.0d0)
(defparameter *lerp-mouse-y* 0.0d0)
(defun update-moused (clamp &optional (smoothing-factor 1.0))
  (multiple-value-bind (dx dy) (cursor-motion-difference)
    (let ((x (+ *mouse-x* dx))
	  (y (+ *mouse-y* dy)))
      ;;So looking straight up stops.
      (when (> y clamp)
	(setf y clamp))
      ;;So looking straight down stops
      (let ((negative (- clamp)))
	(when (< y negative)
	  (setf y negative)))
      (setf *mouse-x* x)
      (setf *mouse-y* y)))
  ;;*lerp-mouse-x* and *lerp-mouse-y* are used
  ;;for camera smoothing with the framerate.
  (setf *lerp-mouse-x* (alexandria:lerp smoothing-factor *lerp-mouse-x* *mouse-x*))
  (setf *lerp-mouse-y* (alexandria:lerp smoothing-factor *lerp-mouse-y* *mouse-y*)))
(defparameter *mouse-multiplier* 0.002617)
(defparameter *mouse-multiplier-aux* (/ (* 0.5 pi 0.9999) *mouse-multiplier*))
(defun neck-values ()
  (values
   (floatify (* *lerp-mouse-x* *mouse-multiplier*))
   (floatify (* *lerp-mouse-y* *mouse-multiplier*))))

(defun unit-pitch-yaw (pitch yaw &optional (result (sb-cga:vec 0.0 0.0 0.0)))
  (setf yaw (- yaw))
  (let ((cos-pitch (cos pitch)))
    (with-vec (x y z) (result symbol-macrolet)
      (setf x (* cos-pitch (sin yaw))
	    y (- (sin pitch))
	    z (* cos-pitch (cos yaw)))))
  result)

;;;;************************************************************************;;;;
;;emacs-like modes
(defparameter *active-modes* ())
(defun reset-all-modes ()
  (setf *active-modes* nil))
(defun enable-mode (mode)
  (pushnew mode *active-modes* :test 'equal))
(defun disable-mode (mode)
  (setf *active-modes* (delete mode *active-modes*)))
(defun mode-enabled-p (mode)
  (member mode *active-modes* :test 'equal))
(defun set-mode-if (mode p)
  (if p
      (enable-mode mode)
      (disable-mode mode)))
;;;;************************************************************************;;;;

(defparameter *session* nil)
(defparameter *ticks* 0)
(defparameter *game-ticks-per-iteration* 0)
(defparameter *fraction-for-fps* 0.0)

(defparameter *entities* nil)
(defparameter *ent* nil)

(defparameter *fov* (floatify (* pi (/ 85 180))))
(defparameter *camera*
  (camera-matrix:make-camera
   :frustum-far (* 256.0)
   :frustum-near (/ 1.0 8.0)))
(defparameter *fog-ratio* 0.75)
(defparameter *time-of-day* 1.0)
(defparameter *sky-color*
  (mapcar 'utility:byte/255
	  '(128 128 128)))
(defun atmosphere ()
  (let ((sky (mapcar 
	      (lambda (x)
		(alexandria:clamp (* x *time-of-day*) 0.0 1.0))
	      *sky-color*))
	(fog *fog-ratio*))
    (values
     (mapcar
      (lambda (a b)
	(alexandria:lerp *fade* a b))
      *fade-color*
      sky)
     (alexandria:lerp *fade* 1.0 *fog-ratio*))))
(defparameter *fade-color* '(0.0 0.0 0.0))
(defparameter *fade* 1.0)

;;*frame-time* is for graphical frames, as in framerate.
(defparameter *frame-time* 0)
(defun sucle-per-frame ()
  (incf *frame-time*)

  ;;set the chunk center aroun the player
  (livesupport:update-repl-link)
  (application:on-session-change *session*
    ;;(voxel-chunks:clearworld)
    (setf *entities* (loop :repeat 10 :collect (create-entity)))
    (setf *ent* (elt *entities* 0))

    ;;Controller?
    (reset-all-modes)
    (enable-mode :normal-mode)
    (enable-mode :god-mode)

    )
  (gl:polygon-mode :front-and-back :line)

  ;;Polling
  ;;Physics
  ;;Rendering Chunks
  ;;Rendering Other stuff
  ;;Meshing
  ;;Waiting on vsync
  ;;Back to polling
  
  ;;Physics and Polling should be close together to prevent lag
  
  ;;physics

  (when (mode-enabled-p :god-mode)
    (run-buttons *god-keys*))
  (when (mode-enabled-p :movement-mode)
    ;;Set the sneaking state
    (setf (entity-sneak? *ent*)
	  (cond
	    ((window:button :key :down :left-shift)
	     0)
	    ((window:button :key :down :left-control)
	     1)))
    ;;Jump if space pressed
    (setf (entity-jump? *ent*)
	  (window:button :key :down #\Space))
    (when (window:button :key :pressed #\Space)
      (set-doublejump *ent*))
    ;;Set the direction with WASD
    (setf
     (entity-hips *ent*)
     (let ((x 0)
	   (y 0))
       (when (window:button :key :down #\w)
	 (incf x))
       (when (window:button :key :down #\s)
	 (decf x))
       (when (window:button :key :down #\a)
	 (decf y))
       (when (window:button :key :down #\d)
	 (incf y))
       ;;[FIXME]
       ;;This used to be cached and had its own function in
       ;;the control.asd
       (if (and (zerop x)
		(zerop y))
	   nil			   
	   (floatify (atan y x)))))
    ;;update the internal mouse state
    ;;taking into consideration fractions
    (when (window:mouse-locked?)
      (update-moused *mouse-multiplier-aux* 1.0)))
  (when (mode-enabled-p :normal-mode)
    ;;[FIXME] because this runs after update-moused, the camera swivels
    ;;unecessarily.
    (run-buttons *normal-keys*))
  (let ((number-key (control:num-key-jp :pressed)))
    (when number-key
      (setf *ent* (elt *entities* number-key))))
  
  ;;Set the pitch and yaw of the player based on the
  ;;mouse position
  (mvc 'set-neck-values (entity-neck *ent*) (neck-values))

  ;;Run the game ticks

  ;;FIXME:: run fps:tick if resuming from being paused.
  (setf
   (values *fraction-for-fps* *game-ticks-per-iteration*)
   (fps:tick
     (incf *ticks*)
     (setf *time-of-day* 1.0)
     ;;run the physics
     (run-physics-for-entity *ent*)))
  ;;render chunks and such
  ;;handle chunk meshing
  (sync_entity->camera *ent* *camera*)
  
  (draw-to-default-area)
  ;;this also clears the depth and color buffer.
  (multiple-value-bind (color fog) (atmosphere)
    (apply #'render-sky color)
    (render-chunks::use-chunk-shader
     :camera *camera*
     :sky-color color
     :time-of-day (* *fade* *time-of-day*)
     :fog-ratio fog
     :chunk-radius 16 ;;(vocs::cursor-radius *chunk-cursor-center*)
     ))

  (render-chunks::render-chunks)
  
  ;;selected block and crosshairs
  (use-solidshader *camera*)
  (map nil
       (lambda (ent)
	 (unless (eq ent *ent*)
	   (render-entity ent)))
       *entities*)
  ;;#+nil
  (progn
    (gl:line-width 10.0)
    (map nil
	 (lambda (ent)
	   (when (eq ent (elt *entities* 0))
	     (let ((*camera* (camera-matrix:make-camera)))
	       (sync_entity->camera ent *camera*)
	       (render-camera *camera*))))
	 *entities*))

  ;;#+nil
  (progn
    (gl:line-width 10.0)
    (render-units))
  ;;(mvc 'render-line 0 0 0 (spread '(200 200 200)))
  (render-crosshairs)

  )


(defun render-camera (camera)
  (mapc (lambda (arg)
	  (mvc 'render-line-dx
	       (spread (camera-matrix:camera-vec-position camera))
	       (spread (map 'list
			    (lambda (x)
			      (* x 100))
			    arg))))
	(camera-matrix::camera-edges camera))
  (mapc (lambda (arg)
	  (mvc 'render-line-dx
	       (spread (camera-matrix:camera-vec-position camera))
	       (spread (map 'list
			    (lambda (x)
			      (* x 100))
			    arg))
	       0.99 0.8 0.0))
	(camera-matrix::camera-planes camera)))

(defun render-units (&optional (foo 100))
  ;;X is red
  (mvc 'render-line 0 0 0 foo 0 0 (spread #(1.0 0.0 0.0)))
  ;;Y is green
  (mvc 'render-line 0 0 0 0 foo 0 (spread #(0.0 1.0 0.0)))
  ;;Z is blue
  (mvc 'render-line 0 0 0 0 0 foo (spread #(0.0 0.0 1.0))))

(defun sync_entity->camera (entity camera)
  ;;FIXME:this lumps in generating the other cached camera values,
  ;;and the generic used configuration, such as aspect ratio and fov.
  
  ;;Set the direction of the camera based on the
  ;;pitch and yaw of the player
  (sync_neck->camera (entity-neck entity) camera)
  ;;Calculate the camera position from
  ;;the past, current position of the player and the frame fraction
  (sync_particle->camera
   ;;modify the camera for sneaking
   (let ((particle (entity-particle entity)))
     (if (and (not (entity-fly? entity))
	      (eql 0 (entity-sneak? entity)))
	 (translate-pointmass particle 0.0 -0.125 0.0)
	 particle))
   camera
   *fraction-for-fps*)
  ;;update the camera
  ;;FIXME::these values are
  (set-camera-values
   camera
   (/ (floatify window:*height*)
      (floatify window:*width*)
      )
   *fov*
   (* 1024.0 256.0)
   )
  (camera-matrix:update-matrices camera)
  ;;return the camera, in case it was created.
  (values camera))
(defun set-camera-values (camera aspect-ratio fov frustum-far)
  (setf (camera-matrix:camera-aspect-ratio camera) aspect-ratio)
  (setf (camera-matrix:camera-fov camera) fov)
  (setf (camera-matrix:camera-frustum-far camera) frustum-far))
(defun sync_particle->camera (particle camera fraction)
  (let* ((prev (pointmass-position-old particle))
	 (curr (pointmass-position particle)))
    (let ((vec (camera-matrix:camera-vec-position camera)))
      (nsb-cga:%vec-lerp vec prev curr fraction))))
(defun sync_neck->camera (neck camera)
  (unit-pitch-yaw (necking-pitch neck)
		  (necking-yaw neck)
		  (camera-matrix:camera-vec-forward camera)))

;;;;************************************************************************;;;;

(defparameter *normal-keys*
  `(((:key :pressed :escape) .
     ,(lambda ()
	(window:get-mouse-out)
	(app:pop-mode)))
    ((:key :pressed #\e) .
     ,(lambda ()
	(cursor-motion-difference)
	(window:toggle-mouse-capture)
	(set-mode-if :movement-mode (not (window:mouse-free?)))
	(set-mode-if :fist-mode (not (window:mouse-free?)))
	;;Flush changes to the mouse so
	;;moving the mouse while not captured does not
	;;affect the camera
	;;FIXME::not implemented.
	;;(moused)
	))))
(defparameter *god-keys*
  `(;;Toggle noclip with 'v'
    ((:key :pressed #\v) .
     ,(lambda () (toggle (entity-clip? *ent*))))
    ;;Toggle flying with 'f'
    ((:key :pressed #\f) .
     ,(lambda () (toggle (entity-fly? *ent*))
	      (toggle (entity-gravity? *ent*))))))
