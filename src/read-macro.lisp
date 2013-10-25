;;; This file tries to define macro, which are combination of read-macro-token and
;;; ordinary macro

(in-package cl-read-macro-tokens)

(defclass tautological-read-macro-token ()
  ((name :initform (error "Name of tautological class should be supplied")
         :initarg :name)))

(defgeneric read-handler (obj stream token)
  (:documentation "Main method to define behaviour of tautological macro-tokens.")
  (:method ((obj tautological-read-macro-token) stream token)
    (format t "Im in tautological core.~%")
    `(,(slot-value obj 'name) ,@(read-list-old stream token))))

(defun read-macro-token-p (symb)
  (gethash symb *read-macro-tokens*))

(defparameter *read-macro-tokens-classes* (make-hash-table :test #'eq))
(defparameter *read-macro-tokens-instances* (make-hash-table :test #'eq))

(defmacro! defmacro!! (name args reader-init &body body)
  (multiple-value-bind (forms decls doc) (defmacro-enhance::parse-body body)
    (let ((readmacro-tokens (or (remove-duplicates
                                 (remove-if-not #'identity
                                                (mapcar (lambda (x)
                                                          (gethash x *read-macro-tokens-classes*))
                                                        (remove-if-not #'read-macro-token-p
                                                                       (alexandria:flatten forms)))))
                                '(tautological-read-macro-token)))
          ;; All these under-the-hood classes names should be somewhere, right?
          ;; Originally I wanted them to be GENSYMs, but this seems to break
          ;; CLOS machinery somehow (it starts complaining about forward-referenced classes)
          (myclass (intern (string name) "CL-READ-MACRO-TOKENS")))
      `(eval-when (:compile-toplevel :load-toplevel :execute)
         (defclass ,myclass ,readmacro-tokens ())
         (defmethod read-handler :around ((,e!-obj ,myclass) ,e!-stream ,e!-token)
                    ;; Yes, this injection of OBJ, STREAM and TOKEN is intended
                    ,(or reader-init '(call-next-method)))
         (setf (gethash ',name *read-macro-tokens-classes*) ',myclass
               (gethash ',name *read-macro-tokens-instances*) (make-instance ',myclass
                                                                             :name ',name))
         (setf (gethash ',name *read-macro-tokens*)
               (lambda (stream token)
                 (read-handler (gethash ',name *read-macro-tokens-instances*)
                               stream token)))
         (defmacro ,name ,args
           ,@(if doc `(,doc))
           ,@decls
           ,@body)))))

