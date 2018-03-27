(in-package :aplayground)

(progn
  (defun map-symbol-ascii (hash)
    (dolist (x (quote ((:space 32)
		       (:apostrophe 39)
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
		       (:semicolon 59)
		       (:equal 61)
		       (:A 97) (:B 98) (:C 99) (:D 100) (:E 101) (:F 102) (:G 103) (:H 104) (:I 105)
		       (:J 106) (:K 107) (:L 108) (:M 109) (:N 110) (:O 111) (:P 112) (:Q 113)
		       (:R 114) (:S 115) (:T 116) (:U 117) (:V 118) (:W 119) (:X 120) (:Y 121)
		       (:Z 122)
		       (:left-bracket 91)
		       (:backslash 92)
		       (:right-bracket 93)
		       (:grave-accent 96))))
      (let ((keyword (pop x))
	    (number (pop x)))
	(setf (gethash keyword hash) number)))
    hash)
  (defparameter *keyword-ascii* (map-symbol-ascii (make-hash-table :test 'eq))))
(defun keyword-code (keyword)
  (gethash keyword *keyword-ascii*))
