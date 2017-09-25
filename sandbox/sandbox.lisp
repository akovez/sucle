(in-package #:sandbox)

(defun initialization1 ()
  (clrhash *g/call-list*)
  (clrhash *g/chunk-call-list*)

  (glinnit) ;opengl
  (physinnit) ;physics
  )
(defun thunkit (control-state)
  (physics control-state))
(defparameter *save* (case 0
		       (0 #P"terrarium2/")
		       (1 #P"first/")
		       (2 #P"second/")
		       (3 #P"third/")
		       (4 #P"fourth/")
		       (5 #P"world/")
		       (6 #P"terrarium/")
		       (7 #P"holymoly/")
		       (8 #P"funkycoolclimb/")
		       (9 #P"ahole/")
		       (10 #P"maze-royale/")
		       (11 #P"bloodcut/")
		       (12 #P"wasteland/")))

(defparameter *saves-dir* (merge-pathnames #P"sandbox-saves/"
					   "/home/imac/Documents/lispysaves/saves/"))

(defun save (filename &rest things)
  (let ((path (merge-pathnames filename *saves-dir*)))
    (with-open-file (stream path :direction :output :if-does-not-exist :create :if-exists :supersede)
      (dolist (thing things)
	(print thing stream)))))

(defun save2 (thingfilename &rest things)
  (apply #'save (merge-pathnames (format nil "~s" thingfilename) *save*) things))

(defun savechunk (position)
  (let ((position-list (multiple-value-list (world:unhashfunc position))))
    (save2 position-list
	   (gethash position world:chunkhash)
	   (gethash position world:lighthash)
	   (gethash position world:skylighthash))))

(defun save-world ()
  (maphash (lambda (k v)
	     (declare (ignorable v))
	     (savechunk k))
	   world:chunkhash))

(defun looad-world ()
  (let ((files (uiop:directory-files (merge-pathnames *save* *saves-dir*))))
    (dolist (file files)
      (loadchunk (apply #'world:chunkhashfunc (read-from-string (pathname-name file)))))))

(defun myload2 (thingfilename)
  (myload (merge-pathnames (format nil "~s" thingfilename) *save*)))

(defun myload (filename)
  (let ((path (merge-pathnames filename *saves-dir*)))
    (let ((things nil))
      (with-open-file (stream path :direction :input :if-does-not-exist nil)
	(tagbody rep
	   (let ((thing (read stream nil nil)))
	     (when thing
	       (push thing things)
	       (go rep)))))
      (nreverse things))))

(defun loadchunk (position)
  (let ((position-list (multiple-value-list (world:unhashfunc position))))
    (let ((data (myload2 position-list)))
      (when data 
	(destructuring-bind (blocks light sky) data
	  (setf (gethash position world:chunkhash)
		(coerce blocks '(simple-array (unsigned-byte 8) (*))))
	  (setf (gethash position world:lighthash)
		(coerce light '(simple-array (unsigned-byte 4) (*))))
	  (setf (gethash position world:skylighthash)
		(coerce sky '(simple-array (unsigned-byte 4) (*)))))
	(return-from loadchunk t)))))  



(defparameter *box* #(0 128 0 128 -128 0))
(with-unsafe-speed
  (defun map-box (func box)
    (declare (type (function (fixnum fixnum fixnum)) func))
    (etouq
     (with-vec-params (quote (x0 x1 y0 y1 z0 z1)) (quote (box))
		      (quote (dobox ((x x0 x1)
				     (y y0 y1)
				     (z z0 z1))
				    (funcall func x y z)))))))
(defun invert (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (if (= blockid 0)
		   (plain-setblock x y z 1 ;(aref #(56 21 14 73 15) (random 5))
				   0
				   )
		   (plain-setblock x y z 0 0)
		   )))
	   box))

(defun grassify (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (when (= blockid 3)
		 (let ((idabove (world:getblock x (1+ y) z)))
		   (when (zerop idabove)
		     (plain-setblock x y z 2 0))))))
	   box))

(defun dirts (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (when (= blockid 1)
		 (when (or (zerop (world:getblock x (+ 2 y) z))
			   (zerop (world:getblock x (+ 3 y) z)))
		   (plain-setblock x y z 3 0)))))
	   box))


(defun simple-relight (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
					;(unless (zerop blockid))
	       (let ((light (aref mc-blocks::lightvalue blockid)))
		 (if (zerop light)
		     (plain-setblock x y z blockid light 0)
		     (setblock-with-update x y z blockid light)))))
	   box)
  (map-box (function sky-light-node) #(0 128 128 129 -128 0))
  (map-box (function light-node) #(0 128 128 129 -128 0)))

(defun neighbors (x y z)
  (let ((tot 0))
    (macrolet ((aux (i j k)
		 `(unless (zerop (world:getblock (+ x ,i) (+ y ,j) (+ z ,k)))
		   (incf tot))))
      (aux 1 0 0)
      (aux -1 0 0)
      (aux 0 1 0)
      (aux 0 -1 0)
      (aux 0 0 1)
      (aux 0 0 -1))
    tot))

(defun bonder (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (unless (zerop blockid)
		 (let ((naybs (neighbors x y z)))
		   (when (> 3 naybs)		     
		     (plain-setblock x y z 0 0 0))))))
	   box))

(defun bonder2 (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (when (zerop blockid)
		 (let ((naybs (neighbors x y z)))
		   (when (< 2 naybs)		     
		     (plain-setblock x y z 1 0 0))))))
	   box))

(defun invert-light (&optional (box *box*))
  (map-box (lambda (x y z)
	     (when (zerop (world:getblock x y z))
	       (let ((blockid (world:getlight x y z))
		     (blockid2 (world:skygetlight x y z)))
	;	 (Setf (world:getlight x y z) (- 15 blockid))
		 (Setf (world:skygetlight x y z) (- 15 blockid2)))))
	   box))


(defun edge-bench (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (unless (zerop blockid)
		 (when (= 4 (neighbors x y z))
		   (plain-setblock x y z 58 0 0)))))
	   box))

(defun corner-obsidian (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (unless (zerop blockid)
		 (when (= 3 (neighbors x y z))
		   (plain-setblock x y z 49 0 0)))))
	   box))


(defun clearblock? (id &optional (box *box*))
  (declare (type fixnum id))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (when (= blockid id)
		 (plain-setblock x y z 0 0))))
	   box))

(defun clearblock2 (id &optional (box *box*))
  (declare (type (unsigned-byte 8) id))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (unless (zerop blockid)
		 (plain-setblock x y z id 0))))
	   box))

(defun seed (id chance &optional (box *box*))
  (declare (type (unsigned-byte 8) id))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (when (and (zerop blockid)
			  (zerop (random chance)))
		 (plain-setblock x y z id 0))))
	   box))

(defun grow (old new)
  (sandbox::map-box (lambda (x y z)
			  (let ((naybs (sandbox::neighbors2 x y z old)))
			    (when (and (not (zerop naybs))
				       (zerop (world:getblock x y z))
				       (zerop (random (- 7 naybs))))
			      (sandbox::plain-setblock x y z new 0)))) sandbox::*box*))

(defun bub (new)
  (sandbox::map-box
   (lambda (x y z)
     (let ((naybs (sandbox::neighbors2 x y z 0)))
       (when (and (not (zerop naybs))
		  (not (zerop (world:getblock x y z))))
	 (sandbox::plain-setblock x y z new 0)))) sandbox::*box*))

(defun bub2 (new)
  (sandbox::map-box
   (lambda (x y z)
     (let ((naybs (sandbox::neighbors2 x y z 45)))
       (when (and (not (zerop naybs))
		  (not (or (zerop (world:getblock x y z))
			   (= 45 (world:getblock x y z)))))
	 (sandbox::plain-setblock x y z new 0)))) sandbox::*box*))

(defun sheath (old new)
  (sandbox::map-box
   (lambda (x y z)
     (let ((naybs (sandbox::neighbors2 x y z old)))
       (when (and (not (zerop naybs))
		  (zerop (world:getblock x y z)))
	 (sandbox::plain-setblock x y z new 0)))) sandbox::*box*))

(defun neighbors2 (x y z w)
  (let ((tot 0))
    (macrolet ((aux (i j k)
		 `(when (= w (world:getblock (+ x ,i) (+ y ,j) (+ z ,k)))
		   (incf tot))))
      (aux 1 0 0)
      (aux -1 0 0)
      (aux 0 1 0)
      (aux 0 -1 0)
      (aux 0 0 1)
      (aux 0 0 -1))
    tot))

(defun testicle (&optional (box *box*))
  (dotimes (x 1)
    (sandbox::edge-bench box)
    (sandbox::corner-obsidian box)
    (sandbox::clearblock? 49 box)
    (sandbox::clearblock? 58 box)
    (dotimes (x 3) (sandbox::bonder box))))

(defun huuh ()
  (world:clearworld)
  (sandbox::seed 1 10000)
  (dotimes (x 30)
    (grow 1 1))
  (dotimes (x 10)
    (bonder))
  (sandbox::invert)
  (dotimes (x 10)
    (bonder))
  (dotimes (x 4)
    (sandbox::invert)
    (dotimes (x (1+ (random 4)))
      (sandbox::testicle)))
  (dirts)
  (grassify)
  (simple-relight))

(defun growdown (old new)
  (sandbox::map-box (lambda (x y z)
			  (let ((naybs (sandbox::neighbors3 x y z old)))
			    (when (and (not (zerop naybs))
				       (zerop (world:getblock x y z))
				       (zerop (random (- 7 naybs))))
			      (sandbox::plain-setblock x y z new 0)))) sandbox::*box*))

(defun neighbors3 (x y z w)
  (let ((tot 0))
    (macrolet ((aux (i j k)
		 `(when (= w (world:getblock (+ x ,i) (+ y ,j) (+ z ,k)))
		   (incf tot))))
      (aux 1 0 0)
      (aux -1 0 0)
      (aux 0 1 0)
      (aux 0 0 1)
      (aux 0 0 -1))
    tot))

(defun clearblock3 (id other &optional (box *box*))
  (declare (type (unsigned-byte 8) id))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
	       (when (= other blockid)
		 (plain-setblock x y z id 0))))
	   box))

#(1 2 3 4 5 7 12 13 ;14
  15 16 17 18 19 21 22 23 24 25 35 41 42 43 45 46 47 48 49
   54 56 57 58 61 61 73 73 78 82 84 86 87 88 89 91 95)

'("lockedchest" "litpumpkin" "lightgem" "hellsand" "hellrock" "pumpkin"
 "jukebox" "clay" "snow" "oreRedstone" "oreRedstone" "furnace" "furnace"
 "workbench" "blockDiamond" "oreDiamond" "chest" "obsidian" "stoneMoss"
 "bookshelf" "tnt" "brick" "stoneSlab" "blockIron" "blockGold" "cloth"
 "musicBlock" "sandStone" "dispenser" "blockLapis" "oreLapis" "sponge" "leaves"
 "log" "oreCoal" "oreIron" "oreGold" "gravel" "sand" "bedrock" "wood"
 "stonebrick" "dirt" "grass" "stone")

(defun platt (x y z)
	(dobox ((x0 (1- x) (+ 2 x))
		(z0 (1- z) (+ 2 z)))
	       (let ((block (world:getblock x0 y z0)))
		 (when (not (or (= block 2) (= block 5)
				(= block 3)))
		   (return-from platt nil))))
	t)

(defun platt2 (x y z)
	(dobox ((x0 (1- x) (+ 2 x))
		(z0 (1- z) (+ 2 z)))
	       (let ((block (world:getblock x0 y z0)))
		 (when (not (or (= block 5) (= block 4)))
		   (return-from platt2 nil))))
	t)

(defun meep ()
  (sandbox::map-box (lambda (x y z)
		      (when (platt x y z)
			(sandbox::plain-setblock x y z 5 0)))
		    sandbox::*box*))
(defun meep2 ()
  (sandbox::map-box (lambda (x y z)
		      (when (platt2 x y z)
			(sandbox::plain-setblock x y z 4 0)))
		    sandbox::*box*))

(defun huhuhuh (xoffset yoffset zoffset)
  (sandbox::map-box
   (lambda (x y z)
     (if (> (1- (/ (expt (/ y 64.0) 2) 2.0))
	    (black-tie:simplex-noise-3d-single-float
	     (/ (floor (/ (+ xoffset x) 8.0)) 8.0)
	     (/ (floor (* (+ yoffset y) (/ 1.0 8.0))) 8.0)
	     (/ (floor (* (+ zoffset z) (/ 1.0 8.0))) 8.0)))
	 (sandbox::plain-setblock x y z 0 0 15)
	 (sandbox::plain-setblock x y z 1 0))) sandbox::*box*))
