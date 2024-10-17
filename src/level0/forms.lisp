(in-package :treep-impl)

(defconstant +kind-class+    (import-lisp-symbol 'class    +symbol-treep+))
(defconstant +kind-function+ (import-lisp-symbol 'function +symbol-treep+))
(defconstant +kind-variable+ (import-lisp-symbol 'variable +symbol-treep+))

(defclass environment ()
  ((bindings :initform (fset:map) :initarg :bindings :accessor environment-bindings)))

(defun augment-environment (environment name kind meaning)
  (flet ((compute-meanings ()
	   (fset:with (or (fset:@ (environment-bindings environment) name)
			  (fset:map))
		      kind
		      meaning)))
    (make-instance 'environment :bindings
		   (fset:with (environment-bindings environment)
			      name
			      (compute-meanings)))))

(defclass form-class (closer-mop:standard-class)
  ((definition :initform nil :accessor form-class-definition)))
(defclass form-slot-definition ()
  ((slot-name :initarg :slot-name :initform nil :accessor slot-name)
   (internal :initarg :internal :initform nil :accessor slot-internal?)))
(defclass direct-form-slot-definition (closer-mop:standard-direct-slot-definition form-slot-definition) ())
(defclass effective-form-slot-definition (closer-mop:standard-effective-slot-definition form-slot-definition) ())

(defmethod closer-mop:validate-superclass ((class form-class) (superclass closer-mop:standard-class))
  t)

(defmethod closer-mop:direct-slot-definition-class ((class form-class) &rest initargs)
  (declare (ignore initargs))
  (find-class 'direct-form-slot-definition))

(defmethod closer-mop:effective-slot-definition-class ((class form-class) &rest initargs)
  (declare (ignore initargs))
  (find-class 'effective-form-slot-definition))

(defconstant +symbol-form+        (import-lisp-symbol 'form   +symbol-treep+))
(defconstant +symbol-form-parent+ (import-lisp-symbol 'parent +symbol-form+))

(defclass form ()
  ((parent :accessor form-parent))
  (:metaclass form-class))
(setf (get 'form 'symbol) +symbol-form+)

(defun slot (name class)
  (or (find-if (lambda (def) (eq name (closer-mop:slot-definition-name def)))
	       (closer-mop:class-slots (if (symbolp class) (find-class class) class)))
      (error "~A does not name a slot in ~A" name class)))

(closer-mop:finalize-inheritance (find-class 'form))
(let ((parent-slot (slot 'parent 'form)))
  (setf (slot-name parent-slot) +symbol-form-parent+)
  (setf (slot-internal? parent-slot) t))

(defmethod internal-slot? (form (slot cl:symbol))
  (slot-internal? (slot slot (class-of form))))
(defmethod internal-slot? (form (slot closer-mop:slot-definition))
  (declare (ignore form slot))
  nil)
(defmethod internal-slot? (form (slot form-slot-definition))
  (declare (ignore form))
  (slot-internal? slot))
(defmethod internal-slot? ((form cl:class) (slot cl:symbol))
  (slot-internal? (slot slot form)))
(defmethod internal-slot? ((form cl:symbol) slot)
  ;; TODO avoid make-instance, use prototype instead
  (internal-slot? (make-instance form) slot))

(defgeneric init-subform (parent name child))
(defmethod init-subform ((parent form) (name (eql 'parent)) (child form))
  nil)
(defmethod init-subform ((parent form) name child)
  nil)
(defmethod init-subform ((parent form) name (child form))
  (setf (form-parent child) parent)) ;;TODO check it doesn't already have a parent

(defmethod initialize-instance :after ((instance form) &key &allow-other-keys)
  (cl:loop
     :for slot :in (closer-mop:class-slots (class-of instance))
     :do (let ((name (closer-mop:slot-definition-name slot)))
	   (if (slot-boundp instance name)
	       (init-subform instance name (cl:slot-value instance name)))))) ;;TODO lists of children

#|TODO move/redo
(defclass constant (form)
  ((value :initarg :value :reader constant-value)))

(defclass variable-access (form)
  ((variable-name :initarg :name :reader accessed-variable-name)))

(defclass variable-read (variable-access) ())

(defclass variable-write (variable-access)
  ((form :initarg :form :reader variable-write-form)))

(defclass function-argument (form)
  ((name :initarg :name :reader function-argument-name :type symbol)))

(defclass optional-function-argument (function-argument)
  ((default-value :initarg :default-value :initform nil :reader function-argument-default-value)))

(defclass rest-function-argument (function-argument) ())

(defclass function (form)
  ((lambda-list :initarg :lambda-list :initform (fset:seq) :reader function-lambda-list)
   (expression :initarg :expression :reader function-expression)))

(defclass variable (form)
  ((init-form :initarg :init-form :initform nil :reader variable-init-form)))

(defclass constant (form)
  ((value :initarg :value :reader constant-value)))

;; A macro is not like in Lisp, i.e., superficially like a function call.
;; It's a new form (class).
(defclass macro (form)
  ((expansion :initarg :expansion :reader macro-expansion)))

(defmethod transform (transformer (form macro) environment)
  (let ((expanded (funcall (macro-expansion form) form environment)))
    (transform transformer expanded environment)))

(defclass function-access (form)
  ((function-designator :initarg :function :reader accessed-function-designator)))

(defclass function-reference (function-access) ())

(defclass function-call (function-access)
  ((arguments :initarg :arguments :reader function-arguments)))

;;Environment and definitions
(defclass definition (form)
  ((name :initarg :name :reader definition-name)))

(defclass binding (form)
  ((definition :initarg :definition :reader binding-definition :type definition)
   (body :initarg :body :reader binding-body)))

(defclass define (form)
  ((definition :initarg :definition :reader define-definition :type definition)))

;;TODO Should this inherit from variable?
(defclass variable-definition (definition)
  ((init-form :initarg :init-form :initform nil :reader variable-definition-init-form)
   (mutable? :initarg :mutable :initform nil :reader mutable?)))

(defclass function-definition (definition)
  ((init-form :initarg :init-form :initform nil :reader function-definition-init-form)))
(defclass macro-definition (definition)
  ((slot-definitions :initarg :slot-definitions :reader macro-definition-slots)
   (expander-function :initarg :expander-function :reader macro-definition-expander-function)))

(defgeneric definition-kind (transformer definition))
(defmethod definition-kind (transformer (definition variable-definition))
  +kind-variable+)
(defmethod definition-kind (transformer (definition function-definition))
  +kind-function+)
|#

(defun initial-bindings ()
  (let ((map (fset:map)))
    (setf map (fset:with map +symbol-form+ (fset:with (fset:map) +kind-class+ (find-class 'form))))
    map))

(defun initial-environment ()
  (make-instance 'environment :bindings (initial-bindings)))

(defvar *environment* (initial-environment))

(defun meaning (symbol kind &optional (environment *environment*))
  (let ((meanings (fset:@ (environment-bindings environment) symbol)))
    (when meanings
      (fset:@ meanings kind))))

(defun copy-environment (&optional (environment *environment*))
  (make-instance 'environment :bindings (environment-bindings environment)))

#|TODO
(defgeneric compute-new-environment-for-definition (transformer definition environment))

(defmethod compute-new-environment-for-definition (transformer (definition definition) environment)
  (augment-environment environment
		       (definition-name definition)
		       (definition-kind transformer definition)
		       (transform transformer definition environment)))

(defmethod transform (transformer (form binding) environment)
  (let ((def (binding-definition form)))
    (transform transformer (binding-body form) (compute-new-environment-for-definition transformer def environment))))

(defmethod transform (transformer (form define) environment)
  (let ((def (define-definition form)))
    (setf (environment-bindings environment)
	  (environment-bindings (compute-new-environment-for-definition transformer def environment)))))
|#
