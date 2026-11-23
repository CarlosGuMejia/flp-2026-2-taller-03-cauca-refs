#lang eopl
;Autores: Jesus David Lopez Diaz 2611029-3743

#|
  Taller 3 — Cauca con referencias y tipos.
  Reglas de tipado y chequeo del programa (Parte 3).

  type-of recorre el árbol con cases sobre un ambiente de tipos y no
  evalúa nada: una regla por variante de expresión, tal como están
  escritas en el cuadro del enunciado.

  Los mensajes de error se distinguen uno de otro. Son los nueve del
  cuadro «Mensajes de error», con ese texto.

  El módulo requiere sintaxis.rkt y tipos.rkt, y ningún otro módulo del
  intérprete: el árbol que recorre es el que produjo el parser, con las
  anotaciones de tipo adentro.
|#

(require "sintaxis.rkt")
(require "tipos.rkt")

;; tipos-de-lista : lista de expresion x tenv -> lista de tipo
;; El tipo de cada expresión de la lista, de izquierda a derecha, bajo el
;; mismo ambiente de tipos.
(define tipos-de-lista
  (lambda (exps amb)
    (if (null? exps)
        '()
        (let ((primero (type-of (car exps) amb)))
          (cons primero (tipos-de-lista (cdr exps) amb))))))

;; tipo-de-escritura : -> tipo
;; El tipo que tienen setref y swap como expresiones. La gramática no tiene
;; un tipo unit, así que retornan num, como el valor arbitrario que
;; retorna setref en EOPL. Si el enunciado dice otro, se cambia aquí.
(define tipo-de-escritura
  (lambda () (num-tipo)))

;; type-of-if : expresion x expresion x expresion x tenv -> tipo
;; La condición debe ser bool y las dos ramas deben tener el mismo tipo,
;; que es el del if.
(define type-of-if
  (lambda (prueba rama-then rama-else amb)
    (let ((t-prueba (type-of prueba amb)))
      (if (not (tipos-iguales? t-prueba (bool-tipo)))
          (eopl:error 'type-of
                      "La condicion del if debe ser bool, se encontro ~a"
                      (tipo->texto t-prueba))
          (let ((t-then (type-of rama-then amb))
                (t-else (type-of rama-else amb)))
            (if (tipos-iguales? t-then t-else)
                t-then
                (eopl:error 'type-of
                            "Las ramas del if deben coincidir: ~a vs ~a"
                            (tipo->texto t-then) (tipo->texto t-else))))))))

;; verificar-argumentos : lista de tipo x lista de tipo x int -> boolean
;; Retorna #t si cada tipo actual es igual al formal de su posición; si no,
;; levanta eopl:error indicando el primer argumento que no coincide (el
;; primero es el 1). Las dos listas tienen la misma longitud.
(define verificar-argumentos
  (lambda (formales actuales posicion)
    (cond
      [(null? formales) #t]
      [(tipos-iguales? (car formales) (car actuales))
       (verificar-argumentos (cdr formales) (cdr actuales) (+ posicion 1))]
      [else
       (eopl:error 'type-of
                   "El argumento ~a debe ser ~a, se encontro ~a"
                   posicion (tipo->texto (car formales))
                   (tipo->texto (car actuales)))])))

;; type-of-apply : tipo x lista de tipo -> tipo
;; Contrato: tipo del operador x tipos de los argumentos -> tipo del
;; resultado. El operador debe ser un procedimiento, recibir tantos
;; argumentos como parámetros tiene y cada uno del tipo declarado.
(define type-of-apply
  (lambda (t-rator t-args)
    (cases tipo t-rator
      (proc-tipo (formales resultado)
                 (if (= (length formales) (length t-args))
                     (begin
                       (verificar-argumentos formales t-args 1)
                       resultado)
                     (eopl:error 'type-of
                                 "El procedimiento espera ~a argumentos y recibio ~a"
                                 (length formales) (length t-args))))
      (else
       (eopl:error 'type-of
                   "Se intento aplicar un valor de tipo ~a"
                   (tipo->texto t-rator))))))

;; verificar-referencias : lista de symbol x lista de tipo x tenv x int -> boolean
;; Contrato: identificadores x tipos formales x ambiente x posición.
;; Propósito: el tipo de cada identificador debe ser igual al del parámetro
;; formal de su posición (mensaje 5 si no) y debe ser una referencia
;; refto(s). Retorna #t o levanta eopl:error.
(define verificar-referencias
  (lambda (ids formales amb posicion)
    (if (null? ids)
        #t
        (let ((t-id (apply-tenv amb (car ids))))
          (if (not (tipos-iguales? t-id (car formales)))
              (eopl:error 'type-of
                          "El argumento ~a debe ser ~a, se encontro ~a"
                          posicion (tipo->texto (car formales)) (tipo->texto t-id))
              (cases tipo t-id
                (ref-tipo (interno)
                          (verificar-referencias (cdr ids) (cdr formales)
                                                 amb (+ posicion 1)))
                (else
                 (eopl:error 'type-of
                             "El argumento ~a de applyref debe ser una referencia, se encontro ~a"
                             posicion (tipo->texto t-id)))))))))

;; type-of-app-ref : tipo x lista de symbol x tenv -> tipo
;; El operador debe ser un procedimiento de tantos parámetros como
;; identificadores se pasan, y cada identificador debe estar ligado a una
;; referencia del tipo que el parámetro formal declara.
(define type-of-app-ref
  (lambda (t-rator ids amb)
    (cases tipo t-rator
      (proc-tipo (formales resultado)
                 (if (= (length formales) (length ids))
                     (begin
                       (verificar-referencias ids formales amb 1)
                       resultado)
                     (eopl:error 'type-of
                                 "El procedimiento espera ~a argumentos y recibio ~a"
                                 (length formales) (length ids))))
      (else
       (eopl:error 'type-of
                   "Se intento aplicar un valor de tipo ~a"
                   (tipo->texto t-rator))))))

;; type-of-ramas-case : tipo x lista de expresion x tenv -> boolean
;; Retorna #t si todas las acciones tienen el tipo dado; si no, levanta
;; eopl:error con los dos tipos que no coinciden.
(define type-of-ramas-case
  (lambda (t-default acciones amb)
    (if (null? acciones)
        #t
        (let ((t-accion (type-of (car acciones) amb)))
          (if (tipos-iguales? t-accion t-default)
              (type-of-ramas-case t-default (cdr acciones) amb)
              (eopl:error 'type-of
                          "Las ramas del case deben coincidir: ~a vs ~a"
                          (tipo->texto t-accion) (tipo->texto t-default)))))))

;; type-of-case : expresion x lista de expresion x expresion x tenv -> tipo
;; El control debe ser num; todas las acciones y la rama otherwise deben
;; tener el mismo tipo, que es el del case.
(define type-of-case
  (lambda (control acciones default amb)
    (let ((t-control (type-of control amb)))
      (if (not (tipos-iguales? t-control (num-tipo)))
          (eopl:error 'type-of
                      "El control del case debe ser num, se encontro ~a"
                      (tipo->texto t-control))
          (let ((t-default (type-of default amb)))
            (begin
              (type-of-ramas-case t-default acciones amb)
              t-default))))))

;; type-of-deref : expresion x tenv -> tipo
;; La expresión debe ser una referencia refto(t); el deref tiene tipo t.
(define type-of-deref
  (lambda (exp amb)
    (let ((t-exp (type-of exp amb)))
      (cases tipo t-exp
        (ref-tipo (interno) interno)
        (else
         (eopl:error 'type-of
                     "deref espera refto(t), se encontro ~a"
                     (tipo->texto t-exp)))))))

;; type-of-setref : expresion x expresion x tenv -> tipo
;; La primera expresión debe ser refto(t) y la segunda debe tener tipo t.
(define type-of-setref
  (lambda (ref valor amb)
    (let ((t-ref (type-of ref amb)))
      (cases tipo t-ref
        (ref-tipo (guardado)
                  (let ((t-valor (type-of valor amb)))
                    (if (tipos-iguales? guardado t-valor)
                        (tipo-de-escritura)
                        (eopl:error 'type-of
                                    "La celda guarda ~a y se intento escribir ~a"
                                    (tipo->texto guardado) (tipo->texto t-valor)))))
        (else
         (eopl:error 'type-of
                     "setref espera refto(t), se encontro ~a"
                     (tipo->texto t-ref)))))))

;; type-of-swap : expresion x expresion x tenv -> tipo
;; Las dos expresiones deben ser referencias al mismo tipo.
(define type-of-swap
  (lambda (ref1 ref2 amb)
    (let ((t1 (type-of ref1 amb))
          (t2 (type-of ref2 amb)))
      (cases tipo t1
        (ref-tipo (interno1)
                  (cases tipo t2
                    (ref-tipo (interno2)
                              (if (tipos-iguales? interno1 interno2)
                                  (tipo-de-escritura)
                                  (eopl:error 'type-of
                                              "swap espera referencias al mismo tipo: ~a vs ~a"
                                              (tipo->texto t1) (tipo->texto t2))))
                    (else
                     (eopl:error 'type-of
                                 "swap espera refto(t), se encontro ~a"
                                 (tipo->texto t2)))))
        (else
         (eopl:error 'type-of
                     "swap espera refto(t), se encontro ~a"
                     (tipo->texto t1)))))))

;; type-of-begin : expresion x lista de expresion x tenv -> tipo
;; Chequea las expresiones en orden; el tipo del begin es el de la última.
(define type-of-begin
  (lambda (primera resto amb)
    (let ((t-primera (type-of primera amb)))
      (if (null? resto)
          t-primera
          (type-of-begin (car resto) (cdr resto) amb)))))

;; tipos-de-procedimientos : lista de lista de tipo x lista de tipo -> lista de tipo
;; Arma el proc-tipo declarado de cada procedimiento de un letrec a partir
;; de los tipos de sus parámetros y de su resultado.
(define tipos-de-procedimientos
  (lambda (tipos-args tipos-res)
    (if (null? tipos-args)
        '()
        (cons (proc-tipo (car tipos-args) (car tipos-res))
              (tipos-de-procedimientos (cdr tipos-args) (cdr tipos-res))))))

;; verificar-cuerpos-letrec : lista de symbol x lista de symbol x lista de lista de symbol
;;                            x lista de lista de tipo x lista de tipo
;;                            x lista de expresion x tenv -> boolean
;; Contrato: nombres, idss, tipos de parámetros, tipos de resultado
;; declarados, cuerpos y ambiente recursivo -> #t.
;; Propósito: chequea cada cuerpo con sus parámetros declarados sobre el
;; ambiente recursivo y exige que su tipo sea el resultado declarado.
(define verificar-cuerpos-letrec
  (lambda (nombres idss tipos-args tipos-res cuerpos amb-rec)
    (if (null? nombres)
        #t
        (let ((t-cuerpo (type-of (car cuerpos)
                                 (tenv-extendido (car idss) (car tipos-args) amb-rec))))
          (if (tipos-iguales? t-cuerpo (car tipos-res))
              (verificar-cuerpos-letrec (cdr nombres) (cdr idss) (cdr tipos-args)
                                        (cdr tipos-res) (cdr cuerpos) amb-rec)
              (eopl:error 'type-of
                          "El procedimiento ~a declara ~a y su cuerpo da ~a"
                          (car nombres) (tipo->texto (car tipos-res))
                          (tipo->texto t-cuerpo)))))))

;; type-of-letrec : lista de tipo x lista de symbol x lista de lista de symbol
;;                  x lista de lista de tipo x lista de expresion x expresion
;;                  x tenv -> tipo
;; Primero se registran los proc-tipo DECLARADOS en un ambiente recursivo,
;; sin mirar los cuerpos; luego se verifica que cada cuerpo dé el resultado
;; declarado; y el tipo del letrec es el de su cuerpo en ese ambiente.
(define type-of-letrec
  (lambda (tipos-res nombres idss tipos-args cuerpos cuerpo amb)
    (let ((amb-rec (tenv-recursivo nombres
                                   (tipos-de-procedimientos tipos-args tipos-res)
                                   amb)))
      (begin
        (verificar-cuerpos-letrec nombres idss tipos-args tipos-res cuerpos amb-rec)
        (type-of cuerpo amb-rec)))))

;; type-of : expresion x tenv -> tipo
;; El tipo de la expresión bajo el ambiente de tipos, o eopl:error con
;; el mensaje que explique el conflicto.
(define type-of
  (lambda (exp amb)
    (cases expresion exp
      (lit-exp (dato) (num-tipo))
      (var-exp (id) (apply-tenv amb id))
      (true-exp () (bool-tipo))
      (false-exp () (bool-tipo))
      (prim-exp (prim rands)
                (tipo-de-primitiva prim (tipos-de-lista rands amb)))
      (if-exp (prueba rama-then rama-else)
              (type-of-if prueba rama-then rama-else amb))
      (let-exp (ids rands body)
               (type-of body (tenv-extendido ids (tipos-de-lista rands amb) amb)))
      (proc-exp (ids tipos body)
                (proc-tipo tipos (type-of body (tenv-extendido ids tipos amb))))
      (app-exp (rator rands)
               (type-of-apply (type-of rator amb) (tipos-de-lista rands amb)))
      (app-ref-exp (rator ids)
                   (type-of-app-ref (type-of rator amb) ids amb))
      (case-exp (control valores acciones default)
                (type-of-case control acciones default amb))
      (newref-exp (e) (ref-tipo (type-of e amb)))
      (deref-exp (e) (type-of-deref e amb))
      (setref-exp (ref e) (type-of-setref ref e amb))
      (swap-exp (ref1 ref2) (type-of-swap ref1 ref2 amb))
      (begin-exp (e es) (type-of-begin e es amb))
      (letrec-exp (tipos-res proc-names idss tipos-args bodies body)
                  (type-of-letrec tipos-res proc-names idss tipos-args bodies body amb)))))

;; type-of-program : programa -> tipo
;; Chequea el programa en el ambiente de tipos inicial.
(define type-of-program
  (lambda (pgm)
    (cases programa pgm
      (a-program (exp) (type-of exp (tenv-inicial))))))

;; tipo-de-texto : string -> string
;; Analiza el texto, lo chequea y describe el tipo resultante.
(define tipo-de-texto
  (lambda (texto)
    (tipo->texto (type-of-program (parser texto)))))

(provide (all-defined-out))