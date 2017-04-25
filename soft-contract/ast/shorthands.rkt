#lang typed/racket/base

(provide (all-defined-out))

(require racket/match
         racket/splicing
         racket/set
         "definition.rkt")

(: -define : Symbol -e → -define-values)
(define (-define x e) (-define-values (list x) e))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Constants & 'Macros'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define -tt (-b #t))
(define -ff (-b #f))
(define -null (-b null))
(define -void (-b (void)))
(define -null-char (-b #\null))
(define -undefined (-b undefined))

(define -cons (-st-mk -𝒾-cons))
(define -car (-st-ac -𝒾-cons 0))
(define -cdr (-st-ac -𝒾-cons 1))
(define -set-cdr! (-st-mut -𝒾-cons 1)) ; HACK for running some scheme programs
(define -cons? (-st-p -𝒾-cons))

(define -mcons (-st-mk -𝒾-mcons))
(define -mcar (-st-ac -𝒾-mcons 0))
(define -mcdr (-st-ac -𝒾-mcons 1))
(define -set-mcar! (-st-mut -𝒾-mcons 0))
(define -set-mcdr! (-st-mut -𝒾-mcons 1))
(define -mpair? (-st-p -𝒾-mcons))

(define -zero (-b 0))
(define -one (-b 1))

(define -box? (-st-p -𝒾-box))
(define -unbox (-st-ac -𝒾-box 0))
(define -box (-st-mk -𝒾-box))
(define -set-box! (-st-mut -𝒾-box 0))

(: -cond : (Listof (Pairof -e -e)) -e → -e)
(define (-cond cases default)
  (foldr (λ ([alt : (Pairof -e -e)] [els : -e])
           (match-define (cons cnd thn) alt)
           (-if cnd thn els))
         default
         cases))

;; Make conjunctive and disjunctive contracts
(splicing-local
    ((: -app/c : Symbol → (Listof (Pairof ℓ -e)) → -e)
     (define ((-app/c o) args)
       (let go ([args : (Listof (Pairof ℓ -e)) args])
         (match args
           ['() 'any/c]
           [(list (cons ℓ e)) e]
           [(cons (cons ℓ e) args*) (-@ o (list e (go args*)) ℓ)]))))
  (define -and/c (-app/c 'and/c))
  (define -or/c (-app/c 'or/c)))

(: -cons/c : -e -e ℓ → -e)
(define (-cons/c c d ℓ)
  (-struct/c -𝒾-cons (list c d) ℓ))

(: -listof : -e ℓ → -e)
(define (-listof c ℓ)
  (define x (+x! 'listof))
  (match-define (list ℓ₀ ℓ₁) (ℓ-with-ids ℓ 2))
  (-μ/c x (-or/c (list (cons ℓ₀ 'null?)
                       (cons ℓ₁ (-cons/c c (-x/c x) ℓ₁))))))

(: -box/c : -e ℓ → -e)
(define (-box/c c ℓ)
  (-struct/c -𝒾-box (list c) ℓ))

(: -list/c : (Listof (Pairof ℓ -e)) → -e)
(define (-list/c args)
  (foldr (λ ([arg : (Pairof ℓ -e)] [acc : -e])
           (match-define (cons ℓ e) arg)
           (-cons/c e acc ℓ))
         'null?
         args))

(: -list : (Listof (Pairof ℓ -e)) → -e)
(define (-list args)
  (match args
    ['() -null]
    [(cons (cons ℓ e) args*)
     (-@ -cons (list e (-list args*)) ℓ)]))

(: -and : -e * → -e)
;; Return ast representing conjuction of 2 expressions
(define -and
  (match-lambda*
    [(list) -tt]
    [(list e) e]
    [(cons e es) (-if e (apply -and es) -ff)]))

(: -comp/c : Symbol -e ℓ → -e)
;; Return ast representing `(op _ e)`
(define (-comp/c op e ℓ)
  (define x (+x! 'cmp))
  (define 𝐱 (-x x))
  (match-define (list ℓ₀ ℓ₁) (ℓ-with-ids ℓ 2))
  (-λ (list x)
      (-and (-@ 'real? (list 𝐱) ℓ₀)
            (-@ op (list 𝐱 e) ℓ₁))))

(: -begin/simp : (∀ (X) (Listof X) → (U X (-begin X))))
;; Smart constructor for begin, simplifying single-expression case
(define/match (-begin/simp xs)
  [((list e)) e]
  [(es) (-begin es)])

(: -begin0/simp : -e (Listof -e) → -e)
(define (-begin0/simp e es)
  (if (null? es) e (-begin0 e es)))