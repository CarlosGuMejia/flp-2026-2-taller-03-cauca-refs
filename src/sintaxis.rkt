#lang eopl
;Autores: Carlos Humberto Gutierrez Mejia 2059817-3743, Juan Eduardo Calderon Jaramillo 2611001-3743, Jesus David Lopez Diaz 2611029-3743

#|
  Taller 3 — Cauca con referencias y tipos.
  Especificación léxica y gramatical.

  Aquí van los tokens, las producciones con las anotaciones de tipo, los
  datatypes que SLLGEN genera a partir de ellas (programa, expresion,
  tipo, primitiva), el scanner y el parser.

  El módulo no requiere ningún otro: lo requieren los cinco del
  intérprete y los dos del chequeador, de modo que la gramática se
  escribe una sola vez y los dos lados recorren el mismo árbol.

  Se parte de la gramática del Taller 2 (mismo léxico, mismas primitivas
  y mismos constructores) y se hacen los dos cambios del enunciado:
  expresiones nuevas del almacén y anotaciones de tipo en proc y letrec.

  CONSTRUCTORES QUE GENERA (campos entre paréntesis; las listas son listas):

  programa
    a-program (exp)

  expresion
    lit-exp (dato)                      var-exp (id)
    true-exp ()                         false-exp ()
    prim-exp (prim rands)               if-exp (test true-exp false-exp)
    let-exp (ids rands body)            app-exp (rator rands)
    case-exp (control valores acciones default)          [igual al Taller 2]
    proc-exp (ids tipos body)                            [NUEVO: lleva tipos]
    letrec-exp (tipos-res proc-names idss tipos-args bodies body)  [NUEVO]
    newref-exp (exp)                    deref-exp (exp)
    setref-exp (ref exp)                swap-exp (ref1 ref2)
    begin-exp (exp exps)                app-ref-exp (rator ids)

  tipo
    num-tipo ()      bool-tipo ()
    ref-tipo (t)     proc-tipo (args res)

  primitiva  (los mismos nombres del Taller 2)
    sum-prim "+"  minus-prim "-"  mult-prim "*"  div-prim "/"
    add-prim "add1"  sub-prim "sub1"
    mayor-prim ">"  mayorigual-prim ">="  menor-prim "<"  menorigual-prim "<="
    igual-prim "=="  not-prim  and-prim  or-prim
    abs-prim  mcd-prim  mcm-prim  promedio-prim  xor-prim  implica-prim
    entre-prim
|#

;;; ==========================================================
;;; 1. Especificación léxica
;;; ==========================================================
;; Comentarios con //, espacios en blanco, números enteros y flotantes con
;; signo, e identificadores que empiezan por letra y siguen con letras,
;; dígitos, guion bajo o signo de interrogación.
;;
;; El guion abre un número negativo solo si lo sigue un dígito; si no, es
;; la primitiva "-". Tampoco choca con la flecha "->" de los tipos: SLLGEN
;; escoge el token más largo, y a igual longitud prefiere la palabra
;; reservada sobre el identificador.

(define especificacion-lexica
  '((espacio-blanco (whitespace) skip)
    (comentario ("//" (arbno (not #\newline))) skip)
    (identificador (letter (arbno (or letter digit "_" "?"))) symbol)
    ;; enteros positivos y negativos
    (numero (digit (arbno digit)) number)
    (numero ("-" digit (arbno digit)) number)
    ;; flotantes positivos y negativos
    (numero (digit (arbno digit) "." digit (arbno digit)) number)
    (numero ("-" digit (arbno digit) "." digit (arbno digit)) number)))

;;; ==========================================================
;;; 2. Especificación gramatical
;;; ==========================================================
;; Cuatro no terminales: programa, expresion, tipo y primitiva.
;; proc-exp y letrec-exp llevan las anotaciones de tipo. El tipo que
;; antecede al nombre en letrec es el del resultado del procedimiento.

(define especificacion-gramatical
  '((programa (expresion) a-program)

    ;; --- lenguaje base (Taller 2) ---
    (expresion (numero) lit-exp)
    (expresion (identificador) var-exp)
    (expresion ("true") true-exp)
    (expresion ("false") false-exp)
    (expresion (primitiva "(" (separated-list expresion ",") ")") prim-exp)
    (expresion ("if" expresion "then" expresion "else" expresion "end") if-exp)
    (expresion ("let" (arbno identificador "=" expresion) "in" expresion "end")
               let-exp)
    (expresion ("apply" expresion "(" (separated-list expresion ",") ")")
               app-exp)
    (expresion ("case" expresion
                (arbno "of" numero "=>" expresion)
                "otherwise" "=>" expresion "end")
               case-exp)

    ;; --- ligadores con anotaciones de tipo (cambian respecto al Taller 2) ---
    (expresion ("proc" "(" (separated-list identificador ":" tipo ",") ")"
                expresion "end")
               proc-exp)
    (expresion ("letrec"
                (arbno tipo identificador
                       "(" (separated-list identificador ":" tipo ",") ")"
                       "=" expresion)
                "in" expresion "end")
               letrec-exp)

    ;; --- Parte 1: almacén ---
    (expresion ("newref" "(" expresion ")") newref-exp)
    (expresion ("deref" "(" expresion ")") deref-exp)
    (expresion ("setref" "(" expresion "," expresion ")") setref-exp)
    (expresion ("swap" "(" expresion "," expresion ")") swap-exp)
    (expresion ("begin" expresion (arbno ";" expresion) "end") begin-exp)

    ;; --- Parte 2: paso por referencia ---
    (expresion ("applyref" expresion "(" (separated-list identificador ",") ")")
               app-ref-exp)

    ;; --- tipos ---
    (tipo ("num") num-tipo)
    (tipo ("bool") bool-tipo)
    (tipo ("refto" "(" tipo ")") ref-tipo)
    (tipo ("(" (separated-list tipo "*") "->" tipo ")") proc-tipo)

    ;; --- primitivas de la base (Taller 2) ---
    (primitiva ("+") sum-prim)
    (primitiva ("-") minus-prim)
    (primitiva ("*") mult-prim)
    (primitiva ("/") div-prim)
    (primitiva ("add1") add-prim)
    (primitiva ("sub1") sub-prim)
    (primitiva (">") mayor-prim)
    (primitiva (">=") mayorigual-prim)
    (primitiva ("<") menor-prim)
    (primitiva ("<=") menorigual-prim)
    (primitiva ("==") igual-prim)
    (primitiva ("not") not-prim)
    (primitiva ("and") and-prim)
    (primitiva ("or") or-prim)

    ;; --- primitivas nuevas del Taller 2 ---
    (primitiva ("abs") abs-prim)
    (primitiva ("mcd") mcd-prim)
    (primitiva ("mcm") mcm-prim)
    (primitiva ("promedio") promedio-prim)
    (primitiva ("xor") xor-prim)
    (primitiva ("implica") implica-prim)
    (primitiva ("entre") entre-prim)))

;;; ==========================================================
;;; 3. Datatypes, scanner y parser
;;; ==========================================================

(sllgen:make-define-datatypes especificacion-lexica especificacion-gramatical)

;; mostrar-datatypes : -> void
;; Lista en pantalla los datatypes que SLLGEN genera a partir de la
;; gramática. Sirve para revisar los nombres de los constructores.
(define mostrar-datatypes
  (lambda ()
    (sllgen:list-define-datatypes especificacion-lexica especificacion-gramatical)))

;; scanner : string -> lista de tokens
;; Convierte el texto de un programa en la lista de sus tokens.
(define scanner
  (sllgen:make-string-scanner especificacion-lexica especificacion-gramatical))

;; parser : string -> programa
;; Convierte el texto de un programa en su árbol de sintaxis abstracta.
(define parser
  (sllgen:make-string-parser especificacion-lexica especificacion-gramatical))

;;; ==========================================================
;;; 4. Auxiliares para imprimir y comparar árboles
;;; ==========================================================

;; primitiva->simbolo : primitiva -> symbol
;; Retorna el nombre del constructor de la primitiva (por ejemplo
;; sum-prim). Sirve para imprimir y comparar árboles en las pruebas.
(define primitiva->simbolo
  (lambda (prim)
    (cases primitiva prim
      (sum-prim () 'sum-prim)
      (minus-prim () 'minus-prim)
      (mult-prim () 'mult-prim)
      (div-prim () 'div-prim)
      (add-prim () 'add-prim)
      (sub-prim () 'sub-prim)
      (mayor-prim () 'mayor-prim)
      (mayorigual-prim () 'mayorigual-prim)
      (menor-prim () 'menor-prim)
      (menorigual-prim () 'menorigual-prim)
      (igual-prim () 'igual-prim)
      (not-prim () 'not-prim)
      (and-prim () 'and-prim)
      (or-prim () 'or-prim)
      (abs-prim () 'abs-prim)
      (mcd-prim () 'mcd-prim)
      (mcm-prim () 'mcm-prim)
      (promedio-prim () 'promedio-prim)
      (xor-prim () 'xor-prim)
      (implica-prim () 'implica-prim)
      (entre-prim () 'entre-prim))))

;; tipo->lista : tipo -> lista
;; Convierte un tipo del AST en una lista con el nombre del constructor
;; al frente, comparable con equal?.
(define tipo->lista
  (lambda (t)
    (cases tipo t
      (num-tipo () (list 'num-tipo))
      (bool-tipo () (list 'bool-tipo))
      (ref-tipo (t1) (list 'ref-tipo (tipo->lista t1)))
      (proc-tipo (args res)
                 (list 'proc-tipo (map tipo->lista args) (tipo->lista res))))))

;; expresion->lista : expresion -> lista
;; Convierte una expresión del AST en una lista de símbolos y datos con
;; el nombre del constructor al frente, comparable con equal?. Los
;; datatypes de SLLGEN no se comparan bien con equal?, por eso las
;; pruebas del parser pasan por esta función.
(define expresion->lista
  (lambda (exp)
    (cases expresion exp
      (lit-exp (dato) (list 'lit-exp dato))
      (var-exp (id) (list 'var-exp id))
      (true-exp () (list 'true-exp))
      (false-exp () (list 'false-exp))
      (prim-exp (prim rands)
                (list 'prim-exp (primitiva->simbolo prim)
                      (map expresion->lista rands)))
      (if-exp (test t f)
              (list 'if-exp (expresion->lista test)
                    (expresion->lista t) (expresion->lista f)))
      (let-exp (ids rands body)
               (list 'let-exp ids (map expresion->lista rands)
                     (expresion->lista body)))
      (proc-exp (ids tipos body)
                (list 'proc-exp ids (map tipo->lista tipos)
                      (expresion->lista body)))
      (app-exp (rator rands)
               (list 'app-exp (expresion->lista rator)
                     (map expresion->lista rands)))
      (letrec-exp (tipos-res proc-names idss tipos-args bodies body)
                  (list 'letrec-exp (map tipo->lista tipos-res) proc-names idss
                        (map (lambda (ts) (map tipo->lista ts)) tipos-args)
                        (map expresion->lista bodies)
                        (expresion->lista body)))
      (case-exp (control valores acciones default)
                (list 'case-exp (expresion->lista control) valores
                      (map expresion->lista acciones)
                      (expresion->lista default)))
      (newref-exp (e) (list 'newref-exp (expresion->lista e)))
      (deref-exp (e) (list 'deref-exp (expresion->lista e)))
      (setref-exp (r e)
                  (list 'setref-exp (expresion->lista r) (expresion->lista e)))
      (swap-exp (r1 r2)
                (list 'swap-exp (expresion->lista r1) (expresion->lista r2)))
      (begin-exp (e es)
                 (list 'begin-exp (expresion->lista e)
                       (map expresion->lista es)))
      (app-ref-exp (rator ids)
                   (list 'app-ref-exp (expresion->lista rator) ids)))))

;; ast->lista : programa -> lista
;; Convierte un programa completo en su representación de lista,
;; (a-program <expresion>), con expresion->lista.
(define ast->lista
  (lambda (pgm)
    (cases programa pgm
      (a-program (exp) (list 'a-program (expresion->lista exp))))))

(provide (all-defined-out))
