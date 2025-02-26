(in-package :sucle)
;;;;************************************************************************;;;;
;;;;<RENDER>

(defun draw-to-default-area ()
  ;;draw to default framebuffer
  (glhelp:bind-default-framebuffer)
  ;;setup clipping area
  (glhelp:set-render-area 0 0 window:*width* window:*height*))

(defun render-sky (x y z)
  (gl:clear-color x y z 1.0)
  ;;change the sky color according to time
  (gl:depth-func :less)
  (gl:clear-depth 1.0)
  (gl:clear :color-buffer-bit :depth-buffer-bit))
(defparameter *position-attr* 0)
(defparameter *texcoord-attr* 2)
;;FIXME::some standard to this? nvidia?
(defparameter *color-attr* 3)

(defparameter *shader-version* 120)
#+nil
(defun test-all-shader-versions ()
  (dolist (x glhelp::*version-data*)
    (setf *shader-version* (second x))
    (deflazy:refresh 'blockshader nil)
    (sleep 0.5)))

(glhelp:deflazy-gl solidshader ()
  (glhelp:create-opengl-shader
   "
out vec3 color_out;
out vec3 position_out;
in vec4 position;
in vec3 color;
uniform mat4 projection_model_view;

void main () {
gl_Position = projection_model_view * position;
color_out = color;
position_out = position.xyz;
}"
   "
in vec3 color_out;
in vec3 position_out;
void main () {
gl_FragColor.a = 1.0;
gl_FragColor.rgb = 
mod((position_out.xyz + 0.7) * vec3(0.05,0.07,0.09), 1.0) *
color_out;
}"
   `(("position" ,*position-attr*) 
     ("color" 3))
   '((:pmv "projection_model_view"))))
(defun render-entity (entity)
  (mvc 'render-aabb-at
       (entity-aabb entity)
       (spread (entity-position entity))))

(defun render-total-bounding-area ()
  (render-aabb-at
   (load-time-value
    (let ((max 1024))
      (create-aabb max max max (- max) (- max) (- max))))
   0 0 0))

(defun render-aabb-at (aabb x y z &optional (r 0.1) (g 0.1) (b 0.1))
  (let ((iterator (scratch-buffer:my-iterator)))
    (let ((times (draw-aabb x y z aabb iterator)))
      (declare (type fixnum times)
	       (optimize (speed 3) (safety 0)))
      ;;mesh-fist-box
      (let ((box
	     ;;[FIXME]why use this *iterator*?
	     ;;inefficient: creates an iterator, and an opengl object, renders its,
	     ;;just to delete it on the same frame
	     (scratch-buffer:flush-bind-in* ((iterator xyz))		    
	       (glhelp:create-vao-or-display-list-from-specs
		(:quads times)
		((*color-attr* r g b)
		 (*position-attr* (xyz) (xyz) (xyz))))
	       )))
	(glhelp:slow-draw box)
	(glhelp:slow-delete box)))))
(defun render-line-dx (x0 y0 z0 dx dy dz &optional (r 0.2) (g 0.0) (b 1.0))
  (render-line x0 y0 z0 (+ x0 dx) (+ y0 dy) (+ z0 dz) r g b))
(defun render-line (x0 y0 z0 x1 y1 z1 &optional (r 0.2) (g 0.0) (b 1.0))
  (floatf x0 y0 z0 x1 y1 z1)
  (let ((thing
	 (let ((iterator (scratch-buffer:my-iterator)))
	   (scratch-buffer:bind-out* ((iterator fun))
	     (fun x0 y0 z0)
	     (fun x1 y1 z1))
	   (scratch-buffer:flush-bind-in*
	       ((iterator xyz))
	     (glhelp:create-vao-or-display-list-from-specs
	      (:lines 2)
	      ((*color-attr* r g b 1.0)
	       (*position-attr* (xyz) (xyz) (xyz) 1.0)))))))
    (glhelp:slow-draw thing)
    (glhelp:slow-delete thing)))
  ;;render crosshairs

(defun render-crosshairs ()
  (glhelp:set-render-area
   (- (/ window:*width* 2.0) 1.0)
   (- (/ window:*height* 2.0) 1.0)
   2
   2)
  (gl:clear-color 1.0 1.0 1.0 1.0)
  (gl:clear
   :color-buffer-bit
   ))

(defun use-solidshader (&optional (camera *camera*))
  (let ((shader (deflazy:getfnc 'solidshader)))
    (glhelp:use-gl-program shader)
    ;;uniform crucial for first person 3d
    (glhelp:with-uniforms
	uniform shader
      (gl:uniform-matrix-4fv 
       (uniform :pmv)
       ;;(nsb-cga:identity-matrix)
       
       (camera-matrix:camera-matrix-projection-view-player camera)
       nil))))


;;;;</RENDER>
;;;;************************************************************************;;;;
;;;;<CHUNK-RENDERING?>

(defun draw-aabb (x y z aabb &optional (iterator *iterator*))
  (let ((minx (aabbcc:aabb-minx aabb))
	(miny (aabbcc:aabb-miny aabb))
	(minz (aabbcc:aabb-minz aabb))
	(maxx (aabbcc:aabb-maxx aabb))
	(maxy (aabbcc:aabb-maxy aabb))
	(maxz (aabbcc:aabb-maxz aabb)))
      aabb
    (draw-box
     (+ minx x -0) (+  miny y -0) (+  minz z -0)
     (+ maxx x -0) (+  maxy y -0) (+  maxz z -0)
     iterator)))

(defun draw-box (minx miny minz maxx maxy maxz &optional (iterator *iterator*))
  (macrolet ((vvv (x y z)
	       `(progn
		  (fun ,x)
		  (fun ,y)
		  (fun ,z))
	       ))
    (scratch-buffer:bind-out* ((iterator fun))
      (vvv minx maxy minz)
      (vvv maxx maxy minz)
      (vvv maxx maxy maxz)
      (vvv minx maxy maxz)

      ;;j-
      (vvv minx miny minz)
      (vvv minx miny maxz)
      (vvv maxx miny maxz)
      (vvv maxx miny minz)

      ;;k-
      (vvv minx maxy minz)
      (vvv minx miny minz)
      (vvv maxx miny minz)
      (vvv maxx maxy minz)

      ;;k+
      (vvv maxx miny maxz)
      (vvv minx miny maxz)
      (vvv minx maxy maxz)
      (vvv maxx maxy maxz)
      
      ;;i-
      (vvv minx miny minz)
      (vvv minx maxy minz)
      (vvv minx maxy maxz)
      (vvv minx miny maxz)

      ;;i+
      (vvv maxx miny minz)
      (vvv maxx miny maxz)
      (vvv maxx maxy maxz)
      (vvv maxx maxy minz))

    (values (* 6 4))))

#+nil
(progn
;;;Frustum culling
;;;http://www.iquilezles.org/www/articles/frustumcorrect/frustumcorrect.htm
  (defun box-in-frustum (camera aabb)
    (let ((planes (camera-matrix::camera-planes camera))
	  (camera-position (camera-matrix::camera-vec-position camera)))
      (dolist (plane planes)
	(let ((out 0))
	  (call-aabb-corners
	   (lambda (x y z)
	     (when (< 0.0
		      (nsb-cga:dot-product
		       (nsb-cga:vec-
			camera-position
			(nsb-cga:vec x y z))
		       plane))
	       (incf out)))
	   aabb)
	  (when (= out 8)
	    (return-from box-in-frustum nil)))))
    (values t))

  (defun call-aabb-corners
      (&optional
	 (fun (lambda (&rest rest) (print rest)))
			 (aabb *player-aabb*))
    (labels ((x (x)
	       (y x (aabbcc:aabb-miny aabb))
	       (y x (aabbcc:aabb-maxy aabb)))
	     (y (x y)
	       (z x y (aabbcc:aabb-minz aabb))
	       (z x y (aabbcc:aabb-maxz aabb)))
	     (z (x y z)
	       (funcall fun x y z)))
      (x (aabbcc:aabb-minx aabb))
      (x (aabbcc:aabb-maxx aabb)))))


;;;; Sync camera to player
(defun sync_entity->camera (entity camera fraction)
  ;;FIXME:this lumps in generating the other cached camera values,
  ;;and the generic used configuration, such as aspect ratio and fov.
  
  ;;Set the direction of the camera based on the
  ;;pitch and yaw of the player
  (sync_neck->camera (entity-neck entity) camera)
  ;;Calculate the camera position from
  ;;the past, current position of the player and the frame fraction
  (sync_particle->camera (entity-particle entity) camera fraction)
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
