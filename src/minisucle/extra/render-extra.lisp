(in-package :sucle)

(defun render-debug (fraction)
  (map nil
       (lambda (ent)
	 (unless (eq ent *ent*)
	   (render-entity ent)))
       *entities*)
  (progn
    (gl:line-width 10.0)
    (map nil
	 (lambda (ent)
	   (when (eq ent (elt *entities* 0))
	     (let ((*camera* (camera-matrix:make-camera)))
	       (sync_entity->camera ent *camera* fraction)
	       (render-camera *camera*))))
	 *entities*))
  (progn
    (gl:line-width 10.0)
    (render-units))
  (mvc 'render-line 0 0 0 (spread '(200 200 200))))


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

(defparameter *selected-block-aabb*
  (let* ((offset 0.01)
	 (small (- 0.0 offset))
	 (large (+ 1.0 offset)))
    (create-aabb large large large small small small)))
;;'render-' type functions write to OpenGL.

(defun render-fist (&optional (fist *fist*))
  (gl:disable :blend)
  (gl:disable :cull-face)
  (gl:polygon-mode :front-and-back :line)
  (gl:line-width 2)
  ;;[FIXME]render the fist again
  (when (fist-exists fist)
    (mvc 'render-aabb-at *selected-block-aabb* (spread (fist-selected-block fist)))))
