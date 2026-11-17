#lang eopl
;Autores: Carlos Humberto Gutierrez Mejia 2059817-3743, Jesus David Lopez Diaz 2611029-3743

#|
  Taller 3 — Cauca con referencias y tipos.
  TAD ambiente y valor procedimiento.

  Las dos definiciones van en el mismo módulo porque se nombran entre
  sí: el campo del ambiente dentro de una clausura pide ambiente?, y
  apply-env construye una clausura cuando resuelve un nombre ligado por
  letrec. En el Taller 2 iban en módulos distintos y el campo env de la
  clausura quedaba con el predicado que acepta cualquier valor; aquí los
  dos predicados quedan en pie.

  Datatypes:
    ambiente
      ambiente-vacio()
      ambiente-extendido(ids, valores, env)
      ambiente-recursivo(proc-names, idss, bodies, env)
    procval
      cerradura(ids, body, env)

  Las anotaciones de tipo no entran aquí: el intérprete las ignora, así
  que la clausura guarda solo los nombres de los parámetros.

  La variante recursiva no construye clausuras: las arma apply-env en el
  momento de la búsqueda, y el ambiente que les entrega es el propio
  ambiente-recursivo (EOPL, sección 3.4, figura 3.9).

  Los valores del ambiente son números, booleanos, procvals y
  referencias; el campo valores es list? porque este módulo no requiere
  almacen.rkt.
|#

(require "sintaxis.rkt")

;; ambiente
;; Contrato: tipo de dato con tres variantes (ambiente-vacio),
;;           (ambiente-extendido ids valores env) y
;;           (ambiente-recursivo proc-names idss bodies env)
;; Propósito: representa una pila de ligaduras. Cada variante apunta al
;; ambiente "de afuera", de modo que la búsqueda recorre de lo más
;; reciente a lo más antiguo.
(define-datatype ambiente ambiente?
  (ambiente-vacio)
  (ambiente-extendido
   (ids (list-of symbol?))
   (valores list?)
   (env ambiente?))
  (ambiente-recursivo
   (proc-names (list-of symbol?))
   (idss list?)
   (bodies (list-of expresion?))
   (env ambiente?)))

;; procval
;; Contrato: tipo de dato (cerradura ids body env)
;; Propósito: representa un procedimiento como código más el ambiente
;; donde nació: parámetros, cuerpo sin evaluar y ambiente de definición.
(define-datatype procval procval?
  (cerradura
   (ids (list-of symbol?))
   (body expresion?)
   (env ambiente?)))

;; buscar-extendido : symbol x (list-of symbol) x list x ambiente -> valor
;; Propósito: auxiliar de apply-env para la variante ambiente-extendido.
;; Recorre en paralelo los ids y los valores de UN marco; si encuentra el
;; id retorna su valor, y si lo agota delega la búsqueda al ambiente de
;; afuera (resto).
(define buscar-extendido
  (lambda (id ids vals resto)
    (cond
      [(null? ids) (apply-env resto id)]
      [(eqv? id (car ids)) (car vals)]
      [else (buscar-extendido id (cdr ids) (cdr vals) resto)])))

;; buscar-recursivo : symbol x (list-of symbol) x list x list x ambiente
;;                    x ambiente -> procval
;; Propósito: auxiliar de apply-env para la variante ambiente-recursivo.
;; Recorre en paralelo nombres, parámetros y cuerpos de los procedimientos
;; del letrec. Si id es uno de ellos, ARMA en ese momento la clausura
;; (cerradura params cuerpo amb-rec), donde amb-rec es el propio
;; ambiente-recursivo: así el cuerpo se ve a sí mismo (y a sus hermanos)
;; y hay recursión. Si no está, delega al ambiente de afuera (resto).
(define buscar-recursivo
  (lambda (id nombres idss bodies amb-rec resto)
    (cond
      [(null? nombres) (apply-env resto id)]
      [(eqv? id (car nombres))
       (cerradura (car idss) (car bodies) amb-rec)]
      [else (buscar-recursivo id (cdr nombres) (cdr idss) (cdr bodies)
                              amb-rec resto)])))

;; apply-env : ambiente x symbol -> valor
;; Busca el identificador en el ambiente, respetando el shadowing de las
;; ligaduras más recientes, y levanta eopl:error si no está ligado.
(define apply-env
  (lambda (env id)
    (cases ambiente env
      (ambiente-vacio ()
        (eopl:error 'apply-env "Variable no ligada: ~s" id))
      (ambiente-extendido (ids vals resto)
        (buscar-extendido id ids vals resto))
      (ambiente-recursivo (proc-names idss bodies resto)
        ;; env (el ambiente-recursivo completo) es el que se entrega
        ;; a la clausura recién armada.
        (buscar-recursivo id proc-names idss bodies env resto)))))

;; ambiente-inicial : -> ambiente
;; El ambiente con que arranca todo programa:
;; n = 10, m = 3, p = 7, q = 2, r = 5.
(define ambiente-inicial
  (lambda ()
    (ambiente-extendido '(n m p q r)
                        '(10 3 7 2 5)
                        (ambiente-vacio))))

(provide (all-defined-out))
