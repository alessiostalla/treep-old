(in-package :treep-impl)

(defmacro define-abstraction (name symbol &optional superclasses slots)
  `(progn
     (defclass ,name ,(or superclasses '(form)) ,slots (:metaclass form-class))
     (setf *environment* (augment-environment *environment* ,symbol +kind-class+ (cl:find-class ',name)))
     (setf (get ',name 'symbol) ,symbol)
     ,@(when slots
	 `((closer-mop:finalize-inheritance (find-class ',name))
	   ,@(remove-if #'null
			(mapcar (lambda (slot)
				  (when (listp slot)
				    (let ((slot-name (getf (cdr slot) :slot-name)))
				      (when slot-name
					`(setf (slot-name (slot ',(car slot) ',name)) ,slot-name)))))
				slots))))
     ',name))

;;Basic forms
(defconstant +symbol-abstraction+                     (import-lisp-symbol 'abstraction         +symbol-treep+))
(defconstant +symbol-abstraction-direct-superclasses+ (import-lisp-symbol 'direct-superclasses +symbol-abstraction+))
(defconstant +symbol-abstraction-slot+                (import-lisp-symbol 'slot                +symbol-abstraction+))
(defconstant +symbol-abstraction-slots+               (import-lisp-symbol 'slots               +symbol-abstraction+))
(defconstant +symbol-name+                            (import-lisp-symbol 'name                +symbol-treep+))
(defconstant +symbol-namespace+                       (import-lisp-symbol 'namespace           +symbol-treep+))
(defconstant +symbol-namespace-search-path+           (import-lisp-symbol 'search-path         +symbol-namespace+))
(defconstant +symbol-quote+                           (import-lisp-symbol 'quote               +symbol-treep+))
(defconstant +symbol-seq+                             (import-lisp-symbol 'seq                 +symbol-treep+))
(defconstant +symbol-seq-elements+                    (import-lisp-symbol 'elements            +symbol-seq+))
(defconstant +symbol-with+                            (import-lisp-symbol 'with                +symbol-treep+))
(defconstant +symbol-with-value+                      (import-lisp-symbol 'value               +symbol-with+))

(define-abstraction quote +symbol-quote+ ()
  ((form :initarg :form :reader quoted-form)))

(define-abstraction seq +symbol-seq+ ()
  ((elements :initarg :elements :accessor seq-elements :initform (fset:seq) :slot-name +symbol-seq-elements+)))

(define-abstraction slot-definition +symbol-abstraction-slot+ ()
  ((name :initarg :name :accessor slot-definition-name :slot-name +symbol-name+)))

(define-abstraction abstraction-definition +symbol-abstraction+ ()
  ((name :initarg :name :accessor abstraction-definition-name :slot-name +symbol-name+)
   (direct-superclasses :initarg :direct-superclasses :accessor abstraction-definition-direct-superclasses :initform (make-instance 'seq)
			:slot-name +symbol-abstraction-direct-superclasses+)
   (slots :initarg :slots :accessor abstraction-definition-slots :initform (make-instance 'seq) :slot-name +symbol-abstraction-slots+)))

(define-abstraction named-child +symbol-with+ ()
  ((name  :initarg :name  :accessor named-child-name  :slot-name +symbol-name+)
   (value :initarg :value :accessor named-child-value :slot-name +symbol-with-value+)))

(define-abstraction namespace +symbol-namespace+ ()
  ((name :reader namespace-name :slot-name +symbol-name+)
   (search-path :reader namespace-search-path :slot-name +symbol-namespace-search-path+)))
  
#| TODO Common forms
(defclass conditional (form)
  ((condition :initarg :condition :reader conditional-if)
   (then :initarg :then :reader conditional-then :type form :initform nil)
   (else :initarg :else :reader conditional-else :type form :initform nil)))

(defclass loop (form)
  ((name :initarg :name :reader loop-name :initform nil)
   (body :initarg :body :reader loop-body)))

(defclass loop-break (form)
  ((loop-name :initarg :loop-name :reader loop-name :initform nil)
   (return-form :initarg :return :reader return-form :initform nil)))
|#
