(defpackage #:queue
  (:use #:cl)
  (:import-from
   #:lparallel.cons-queue
   #:impl)
  (:import-from
   #:lparallel.raw-queue
   #:head
   #:tail)
  (:export 
   #:make-uniq-q
   #:uniq-push
   #:uniq-pop
   #:sort-queue
   ))

(in-package :queue)

;;a fifo queue with the added restriction that members must be unique
(defstruct uniq-q
  (q (lparallel.queue:make-queue))
  (hash (make-hash-table :test 'equal)))

(defun uniq-push (item uniq)
  (lparallel.queue:with-locked-queue (uniq-q-q uniq)
    (let ((hash (uniq-q-hash uniq)))
      (multiple-value-bind (fuck-me exists?) (gethash item hash)
	(declare (ignore fuck-me))
	(unless exists?
	  (setf (gethash item hash) t)
	  (lparallel.queue:push-queue/no-lock item (uniq-q-q uniq)))))))

(defun uniq-pop (uniq)
  (lparallel.queue:with-locked-queue (uniq-q-q uniq)
    (multiple-value-bind (item yup) (lparallel.queue:try-pop-queue/no-lock (uniq-q-q uniq))
      (when yup
	(remhash item (uniq-q-hash uniq)))
      (values item yup))))

(defun %set-queue-internals (list queue)
  (setf (head queue) list
	(tail queue) (last list)))

(defun re-sync-uniq-q (uniq-q)
  (clrhash (uniq-q-hash uniq-q))
  (let ((hash (uniq-q-hash uniq-q))
	(raw-queue (impl (uniq-q-q uniq-q))))
    (dolist (item (head raw-queue))
      (setf (gethash item hash) t))))

(defun sort-queue (queue sort-fun)
  ;;assume that sort-fun does not remove or add any objects, otherwise
  ;;this would screw up the uniq-q
  (lparallel.queue:with-locked-queue (uniq-q-q queue)
    (let ((actual-queue (impl (uniq-q-q queue))))
      (let ((items (head actual-queue)))
	(when items
	  (%set-queue-internals (funcall sort-fun items) actual-queue)
	  (when (typep queue 'uniq-q)
	    (re-sync-uniq-q queue)))))))
