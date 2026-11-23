#lang eopl
;Autores: Jesus David Lopez Diaz 2611029-3743

#|
  Taller 3 — Cauca con referencias y tipos.
  El tipo y el ambiente de tipos (Parte 3).

  El datatype tipo lo genera la gramática, porque las anotaciones se
  escriben dentro del programa. Aquí van la comparación estructural de
  dos tipos, el texto con que un tipo aparece en los mensajes de error y
  el ambiente de tipos.

  Aquí se declara el datatype del ambiente de tipos, con las mismas tres
  variantes del ambiente de valores: tenv-vacio, tenv-extendido y
  tenv-recursivo. La recursiva guarda el tipo declarado de cada
  procedimiento, que es lo que permite chequear el cuerpo de un letrec
  sin evaluarlo.

  El módulo requiere sintaxis.rkt y ningún otro del intérprete.
|#

(require "sintaxis.rkt")

;; unir-con : lista de string x string -> string
;; Une los textos de la lista poniendo el separador entre cada par. La
;; lista vacía da la cadena vacía.
(define unir-con
  (lambda (textos separador)
    (cond
      [(null? textos) ""]
      [(null? (cdr textos)) (car textos)]
      [else (string-append (car textos) separador
                           (unir-con (cdr textos) separador))])))

;; tipo->texto : tipo -> string
;; La forma en que los tipos aparecen en los mensajes de error:
;; "num", "bool", "refto(num)", "(num * num -> bool)". Un procedimiento
;; sin parámetros se escribe "(-> num)".
(define tipo->texto
  (lambda (t)
    (cases tipo t
      (num-tipo () "num")
      (bool-tipo () "bool")
      (ref-tipo (interno) (string-append "refto(" (tipo->texto interno) ")"))
      (proc-tipo (args res)
                 (if (null? args)
                     (string-append "(-> " (tipo->texto res) ")")
                     (string-append "("
                                    (unir-con (map tipo->texto args) " * ")
                                    " -> " (tipo->texto res) ")"))))))

;; listas-de-tipos-iguales? : lista de tipo x lista de tipo -> boolean
;; Compara dos listas de tipos elemento por elemento; deben tener la misma
;; longitud.
(define listas-de-tipos-iguales?
  (lambda (lista1 lista2)
    (cond
      [(null? lista1) (null? lista2)]
      [(null? lista2) #f]
      [else (and (tipos-iguales? (car lista1) (car lista2))
                 (listas-de-tipos-iguales? (cdr lista1) (cdr lista2)))])))

;; tipos-iguales? : tipo x tipo -> boolean
;; Compara dos tipos por estructura, no por identidad: dos tipos son
;; iguales si tienen el mismo constructor y sus componentes son iguales.
(define tipos-iguales?
  (lambda (t1 t2)
    (cases tipo t1
      (num-tipo ()
                (cases tipo t2
                  (num-tipo () #t)
                  (else #f)))
      (bool-tipo ()
                 (cases tipo t2
                   (bool-tipo () #t)
                   (else #f)))
      (ref-tipo (interno1)
                (cases tipo t2
                  (ref-tipo (interno2) (tipos-iguales? interno1 interno2))
                  (else #f)))
      (proc-tipo (args1 res1)
                 (cases tipo t2
                   (proc-tipo (args2 res2)
                              (and (listas-de-tipos-iguales? args1 args2)
                                   (tipos-iguales? res1 res2)))
                   (else #f))))))

;; tenv
;; Contrato: tipo de dato con tres variantes, (tenv-vacio),
;;           (tenv-extendido ids tipos env) y
;;           (tenv-recursivo proc-names proc-tipos env)
;; Propósito: el ambiente de tipos. Asocia cada identificador con su tipo,
;; igual que el ambiente de valores asocia cada uno con su valor. La
;; variante recursiva guarda los nombres de los procedimientos de un
;; letrec con su proc-tipo declarado, para chequear sus cuerpos sin
;; evaluarlos.
(define-datatype tenv tenv?
  (tenv-vacio)
  (tenv-extendido
   (ids (list-of symbol?))
   (tipos (list-of tipo?))
   (env tenv?))
  (tenv-recursivo
   (proc-names (list-of symbol?))
   (proc-tipos (list-of tipo?))
   (env tenv?)))

;; buscar-tipo : symbol x lista de symbol x lista de tipo x tenv -> tipo
;; Recorre en paralelo los nombres y los tipos de UN marco. Si encuentra el
;; identificador retorna su tipo; si agota el marco sigue la búsqueda en el
;; ambiente de afuera.
(define buscar-tipo
  (lambda (id nombres tipos resto)
    (cond
      [(null? nombres) (apply-tenv resto id)]
      [(eqv? id (car nombres)) (car tipos)]
      [else (buscar-tipo id (cdr nombres) (cdr tipos) resto)])))

;; apply-tenv : tenv x symbol -> tipo
;; Busca el tipo del identificador. Si no está declarado levanta
;; eopl:error con «Variable no declarada: <x>».
(define apply-tenv
  (lambda (amb id)
    (cases tenv amb
      (tenv-vacio ()
                  (eopl:error 'apply-tenv "Variable no declarada: ~s" id))
      (tenv-extendido (ids tipos resto)
                      (buscar-tipo id ids tipos resto))
      (tenv-recursivo (proc-names proc-tipos resto)
                      (buscar-tipo id proc-names proc-tipos resto)))))

;; tenv-inicial : -> tenv
;; Declara como num las cinco variables del ambiente inicial.
(define tenv-inicial
  (lambda ()
    (tenv-extendido '(n m p q r)
                    (list (num-tipo) (num-tipo) (num-tipo) (num-tipo) (num-tipo))
                    (tenv-vacio))))

;; primitiva->texto : primitiva -> string
;; El símbolo con que se escribe la primitiva en el programa; sirve para
;; los mensajes de error.
(define primitiva->texto
  (lambda (prim)
    (cases primitiva prim
      (sum-prim () "+")
      (minus-prim () "-")
      (mult-prim () "*")
      (div-prim () "/")
      (add-prim () "add1")
      (sub-prim () "sub1")
      (mayor-prim () ">")
      (mayorigual-prim () ">=")
      (menor-prim () "<")
      (menorigual-prim () "<=")
      (igual-prim () "==")
      (not-prim () "not")
      (and-prim () "and")
      (or-prim () "or")
      (abs-prim () "abs")
      (mcd-prim () "mcd")
      (mcm-prim () "mcm")
      (promedio-prim () "promedio")
      (xor-prim () "xor")
      (implica-prim () "implica")
      (entre-prim () "entre"))))

;; regla-de-primitiva : primitiva -> lista
;; Contrato: primitiva -> (minimo maximo tipo-operandos tipo-resultado)
;; Propósito: lo que la primitiva exige. minimo y maximo son la cantidad
;; de argumentos (maximo es #f si no tiene tope); tipo-operandos es el tipo
;; que deben tener todos los argumentos; tipo-resultado es lo que retorna.
;; Son las mismas aridades que usa el intérprete.
(define regla-de-primitiva
  (lambda (prim)
    (cases primitiva prim
      (sum-prim ()          (list 1 #f (num-tipo) (num-tipo)))
      (minus-prim ()        (list 2 #f (num-tipo) (num-tipo)))
      (mult-prim ()         (list 1 #f (num-tipo) (num-tipo)))
      (div-prim ()          (list 2 #f (num-tipo) (num-tipo)))
      (add-prim ()          (list 1 1  (num-tipo) (num-tipo)))
      (sub-prim ()          (list 1 1  (num-tipo) (num-tipo)))
      (abs-prim ()          (list 1 1  (num-tipo) (num-tipo)))
      (mcd-prim ()          (list 2 #f (num-tipo) (num-tipo)))
      (mcm-prim ()          (list 2 #f (num-tipo) (num-tipo)))
      (promedio-prim ()     (list 1 #f (num-tipo) (num-tipo)))
      (mayor-prim ()        (list 2 2  (num-tipo) (bool-tipo)))
      (mayorigual-prim ()   (list 2 2  (num-tipo) (bool-tipo)))
      (menor-prim ()        (list 2 2  (num-tipo) (bool-tipo)))
      (menorigual-prim ()   (list 2 2  (num-tipo) (bool-tipo)))
      (igual-prim ()        (list 2 2  (num-tipo) (bool-tipo)))
      (entre-prim ()        (list 3 3  (num-tipo) (bool-tipo)))
      (not-prim ()          (list 1 1  (bool-tipo) (bool-tipo)))
      (and-prim ()          (list 2 2  (bool-tipo) (bool-tipo)))
      (or-prim ()           (list 2 2  (bool-tipo) (bool-tipo)))
      (xor-prim ()          (list 2 2  (bool-tipo) (bool-tipo)))
      (implica-prim ()      (list 2 2  (bool-tipo) (bool-tipo))))))

;; verificar-cantidad : string x int x int x (int o #f) -> boolean
;; Retorna #t si la cantidad de argumentos está entre el mínimo y el
;; máximo (sin tope si el máximo es #f); si no, levanta eopl:error.
(define verificar-cantidad
  (lambda (nombre cantidad minimo maximo)
    (cond
      [(and (eqv? minimo maximo) (not (= cantidad minimo)))
       (eopl:error 'tipo-de-primitiva
                   "La primitiva ~a espera ~a argumentos y recibio ~a"
                   nombre minimo cantidad)]
      [(< cantidad minimo)
       (eopl:error 'tipo-de-primitiva
                   "La primitiva ~a espera al menos ~a argumentos y recibio ~a"
                   nombre minimo cantidad)]
      [(and maximo (> cantidad maximo))
       (eopl:error 'tipo-de-primitiva
                   "La primitiva ~a espera ~a argumentos y recibio ~a"
                   nombre maximo cantidad)]
      [else #t])))

;; verificar-operandos : string x lista de tipo x tipo x int -> boolean
;; Retorna #t si todos los tipos de la lista son iguales al esperado; si
;; no, levanta eopl:error indicando el número del primer argumento que no
;; coincide (el primero es el 1).
(define verificar-operandos
  (lambda (nombre tipos esperado posicion)
    (cond
      [(null? tipos) #t]
      [(tipos-iguales? (car tipos) esperado)
       (verificar-operandos nombre (cdr tipos) esperado (+ posicion 1))]
      [else
       (eopl:error 'tipo-de-primitiva
                   "La primitiva ~a espera ~a en el argumento ~a y se encontro ~a"
                   nombre (tipo->texto esperado) posicion
                   (tipo->texto (car tipos)))])))

;; tipo-de-primitiva : primitiva x lista de tipos -> tipo
;; Lo que cada primitiva exige de sus argumentos y lo que retorna: las
;; aritméticas retornan num; las relacionales, las booleanas y entre
;; retornan bool. Verifica la cantidad de argumentos y que todos tengan el
;; tipo que la primitiva pide; si no, levanta eopl:error.
(define tipo-de-primitiva
  (lambda (prim tipos)
    (let* ((regla (regla-de-primitiva prim))
           (minimo (list-ref regla 0))
           (maximo (list-ref regla 1))
           (tipo-operandos (list-ref regla 2))
           (tipo-resultado (list-ref regla 3))
           (nombre (primitiva->texto prim)))
      (begin
        (verificar-cantidad nombre (length tipos) minimo maximo)
        (verificar-operandos nombre tipos tipo-operandos 1)
        tipo-resultado))))

(provide (all-defined-out))