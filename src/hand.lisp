;;;; src/hand.lisp
;;;;
;;;; Copyright 2012-2019 Kimmo "keko" Kenttälä and Michał "phoe" Herda.
;;;;
;;;; Permission is hereby granted, free of charge, to any person obtaining a
;;;; copy of this software and associated documentation files (the "Software"),
;;;; to deal in the Software without restriction, including without limitation
;;;; the rights to use, copy, modify, merge, publish, distribute, sublicense,
;;;; and/or sell copies of the Software, and to permit persons to whom the
;;;; Software is furnished to do so, subject to the following conditions:
;;;;
;;;; The above copyright notice and this permission notice shall be included in
;;;; all copies or substantial portions of the Software.
;;;;
;;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;;;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;;; DEALINGS IN THE SOFTWARE.

(defpackage #:riichi-evaluator.hand
  (:use #:cl
        #:riichi-evaluator.constants
        #:riichi-evaluator.tiles
        #:riichi-evaluator.set)
  (:shadowing-import-from #:riichi-evaluator.set
                          #:set)
  (:local-nicknames (#:a #:alexandria)
                    (#:p #:protest/base)))

(in-package #:riichi-evaluator.hand)

;;; Conditions

(define-condition invalid-hand (riichi-evaluator-error)
  ((%hand :reader invalid-situation-hand :initarg :hand))
  (:default-initargs
   :hand (a:required-argument :hand)))

(define-condition invalid-hand-element (type-error riichi-evaluator-error) ())

(define-condition invalid-situation (invalid-hand simple-condition)
  ((%situation :reader invalid-situation-situation :initarg :situation))
  (:default-initargs
   :situation (a:required-argument :situation)
   :format-control "No reason given.")
  (:report
   (lambda (condition stream)
     (let ((situation (invalid-situation-situation condition)))
       (format stream "Invalid situation ~S for hand ~S:~%~A"
               (if (and (consp situation) (null (cdr situation)))
                   (car situation)
                   situation)
               (invalid-situation-hand condition)
               (apply #'format nil
                      (simple-condition-format-control condition)
                      (simple-condition-format-arguments condition)))))))

(defun invalid-situation (hand situation args format-control &rest format-args)
  (error 'invalid-situation :hand hand :situation (cons situation args)
                            :format-control format-control
                            :format-args format-args))

(define-condition invalid-tile-count (invalid-hand)
  ((%expected :reader invalid-tile-count-expected :initarg :expected)
   (%actual :reader invalid-tile-count-actual :initarg :actual))
  (:default-initargs
   :expected (a:required-argument :expected)
   :actual (a:required-argument :actual))
  (:report (lambda (condition stream)
             (format stream "The hand has ~D tiles, but ~D were expected."
                     (invalid-tile-count-actual condition)
                     (invalid-tile-count-expected condition)))))

(define-condition invalid-same-tile-count (invalid-hand)
  ((%tile :reader invalid-same-tile-count-tile :initarg :tile)
   (%count :reader invalid-same-tile-count-count :initarg :count))
  (:default-initargs
   :tile (a:required-argument :tile)
   :count (a:required-argument :count))
  (:report (lambda (condition stream)
             (format stream
                     "The hand has ~D ~A tiles, but only 4 of them are allowed."
                     (invalid-same-tile-count-count condition)
                     (invalid-same-tile-count-tile condition)))))

;;; Hand

(p:define-protocol-class hand ()
  ((%prevailing-wind :accessor prevailing-wind :initarg :prevailing-wind)
   (%seat-wind :accessor seat-wind :initarg :seat-wind)
   (%winning-tile :accessor winning-tile :initarg :winning-tile)
   (%locked-sets :accessor locked-sets :initarg :locked-sets)
   (%free-tiles :accessor free-tiles :initarg :free-tiles)
   (%dora-list :accessor dora-list :initarg :dora-list)
   (%situations :accessor situations :initarg :situations))
  (:default-initargs
   :prevailing-wind :east :seat-wind :east
   :winning-tile (a:required-argument :winning-tile)
   :locked-sets (a:required-argument :locked-sets)
   :free-tiles (a:required-argument :free-tiles)
   :dora-list (a:required-argument :dora-list)
   :situations '()))

(defgeneric hand-total-visible-tiles (hand)
  (:method-combination append))

(defmethod hand-total-visible-tiles append ((hand hand))
  (append (list (winning-tile hand))
          (mapcar #'tiles (locked-sets hand))
          (free-tiles hand)
          (dora-list hand)))

;; TODO validate that there are at most 4 tiles of any given kind in a hand.

(defun check-hand-elt-type (hand datum expected-type)
  (unless (typep datum expected-type)
    (error 'invalid-hand-element :hand hand :datum datum
                                 :expected-type expected-type)))

(defun check-hand-elt-type-list (hand list expected-type)
  (check-hand-elt-type hand list 'list)
  (dolist (elt list)
    (check-hand-elt-type hand elt expected-type)))

(defun check-hand-situations (hand)
  (dolist (situation (situations hand))
    (if (listp situation)
        (apply #'validate-situation hand situation)
        (validate-situation hand situation))))

(defun check-tile-count (hand)
  (loop for set in (locked-sets hand)
        for (set-count set-extra) = (multiple-value-list (set-tile-count set))
        sum set-count into set-sum
        sum set-extra into set-extra-sum
        finally
           (let ((expected-tile-count (+ 14 set-extra-sum))
                 (actual-tile-count (+ 1 (length (free-tiles hand)) set-sum)))
             (unless (= expected-tile-count actual-tile-count)
               (error 'invalid-tile-count :hand hand
                                          :expected expected-tile-count
                                          :actual actual-tile-count)))))

(defun check-at-most-four-tiles-of-a-kind (hand)
  (let ((tiles (hand-total-visible-tiles hand)))
    (loop for tile in (remove-duplicates tiles :test #'tile=)
          for count = (count-if (a:curry #'tile= tile) tiles)
          unless (<= count 4)
            do (error 'invalid-same-tile-count
                      :hand hand :tile tile :count count))))

(defmethod initialize-instance :after ((hand hand) &key)
  (check-hand-elt-type hand (prevailing-wind hand) '#.`(member ,@*winds*))
  (check-hand-elt-type hand (seat-wind hand) '#.`(member ,@*winds*))
  (check-hand-elt-type hand (winning-tile hand) 'tile)
  (check-hand-elt-type-list hand (locked-sets hand) 'set)
  (check-hand-elt-type-list hand (free-tiles hand) 'tile)
  (check-hand-elt-type hand (dora-list hand) 'cons)
  (check-hand-elt-type-list hand (dora-list hand) 'tile)
  (check-hand-elt-type-list hand (situations hand) `(or keyword (cons keyword)))
  (check-hand-situations hand)
  (check-tile-count hand)
  (check-at-most-four-tiles-of-a-kind hand))

(p:define-protocol-class tsumo-hand (hand) ())
(p:define-protocol-class ron-hand (hand)
  ((%losing-player :accessor losing-player :initarg :losing-player))
  (:default-initargs
   :losing-player (a:required-argument :losing-player)))
(p:define-protocol-class open-hand (hand) ())
(p:define-protocol-class closed-hand (hand)
  ((ura-dora-list :accessor ura-dora-list :initarg :ura-dora-list))
  (:default-initargs
   :ura-dora-list '()))

(defmethod initialize-instance :after ((hand closed-hand) &key)
  (check-hand-elt-type-list hand (ura-dora-list hand) 'tile))

(defmethod hand-total-visible-tiles append ((hand closed-hand))
  (ura-dora-list hand))

;;; Concrete classes

(defclass open-tsumo-hand (open-hand tsumo-hand) ())
(defclass open-ron-hand (open-hand ron-hand) ())
(defclass closed-tsumo-hand (closed-hand tsumo-hand) ())
(defclass closed-ron-hand (closed-hand ron-hand) ())

;;; Situations ;; TODO move into yaku definitions

(defgeneric validate-situation (hand situation &rest args)
  (:method-combination progn))

(defmethod validate-situation progn
    (hand situation &rest args)
  (when (null (compute-applicable-methods
               #'validate-situation (list* hand situation args)))
    (invalid-situation hand situation args "Unknown situation ~S." situation)))

;;; Riichi

(defmethod validate-situation progn
    (hand (situation (eql :riichi)) &rest args)
  (unless (null args)
    (invalid-situation hand situation args
                       "Riichi does not accept arguments.")))

(defmethod validate-situation progn
    ((hand open-hand) (situation (eql :riichi)) &rest args)
  (invalid-situation hand situation args
                     "Riichi cannot be declared on an open hand."))

;;; Double riichi

(defmethod validate-situation progn
    (hand (situation (eql :double-riichi)) &rest args)
  (unless (member :riichi (situations hand))
    (invalid-situation hand situation args
                       "Double riichi cannot occur without riichi."))
  (unless (null args)
    (invalid-situation hand situation args
                       "Double riichi does not accept arguments.")))

;;; Open riichi

(defmethod validate-situation progn
    (hand (situation (eql :open-riichi)) &rest args)
  (unless (member :riichi (situations hand))
    (invalid-situation hand situation args
                       "Open riichi cannot occur without riichi."))
  (unless (null args)
    (invalid-situation hand situation args
                       "Open riichi does not accept arguments.")))

;;; Ippatsu

(defmethod validate-situation progn
    (hand (situation (eql :ippatsu)) &rest args)
  (unless (member :riichi (situations hand))
    (invalid-situation hand situation args
                       "Ippatsu cannot occur without riichi."))
  (unless (null args)
    (invalid-situation hand situation args
                       "Ippatsu does not accept arguments.")))

;;; Tile orderings
