;;;; src/situations.lisp
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

;; TODO package definition here

;; TODO move into yaku definitions
;; TODO invalid-situation tests

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
               (invalid-hand-hand condition)
               (apply #'format nil
                      (simple-condition-format-control condition)
                      (simple-condition-format-arguments condition)))))))

(defun invalid-situation (hand situation args format-control &rest format-args)
  (error 'invalid-situation :hand hand :situation (cons situation args)
                            :format-control format-control
                            :format-args format-args))

(define-condition invalid-dora-list-lengths (invalid-hand) ()
  ((%dora-list :reader dora-list :initarg :dora-list)
   (%ura-dora-list :reader ura-dora-list :initarg :ura-dora-list))
  (:default-initargs
   :dora-list (a:required-argument :dora-list)
   :ura-dora-list (a:required-argument :ura-dora-list))
  (:report
   (lambda (condition stream)
     (format stream "The dora list ~S and ura dora list ~S for hand ~S ~
                       are not of the same length."
             (dora-list condition)
             (ura-dora-list condition)
             (invalid-hand-hand condition)))))

;; (defun check-dora-ura-dora-list-length (hand)
;;   (let ((dora-list-length (length (dora-list hand)))
;;         (ura-dora-list-length (length (ura-dora-list hand))))
;;     (unless (= dora-list-length ura-dora-list-length)
;;       (error 'invalid-dora-list-lengths
;;              :hand hand
;;              :dora-list (dora-list hand)
;;              :ura-dora-list (ura-dora-list hand)))))

(defmethod validate-situation progn
    (hand situation &rest args)
  ;; TODO: In case of no riichi, verify that the list of ura doras is empty.
  ;; How exactly do we achieve that? Dunno. Probably here.
  ;; (check-dora-ura-dora-list-length hand)
  (when (null (compute-applicable-methods
               #'validate-situation (list* hand situation args)))
    (invalid-situation hand situation args "Unknown situation ~S." situation)))

;;; Riichi

(defmethod validate-situation progn
    (hand (situation (eql :riichi)) &rest args)
  ;; TODO: in case of riichi, verify that the list of ura doras is as long as
  ;; the list of doras.
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
