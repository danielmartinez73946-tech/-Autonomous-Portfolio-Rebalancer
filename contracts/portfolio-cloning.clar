;; portfolio-cloning.clar
;; Feature 8: One-Click Portfolio Cloning
;; Enables protocol users to look up the allocations (token weighting) 
;; of another user's public portfolio or a top-performing smart strategy, 
;; and clone those exact allocations into their own active portfolio with a single transaction.

;; =========================================================
;; Constants
;; =========================================================

(define-constant err-no-portfolio      (err u1600))
(define-constant err-private-portfolio (err u1601))
(define-constant err-invalid-weights   (err u1602))

;; =========================================================
;; Data Maps
;; =========================================================

;; Store raw portfolio token structures (Simplified for cloning logic)
;; In production, this would sync closely with `auto-portfolio-rebalancer`
(define-map public-portfolios
    principal
    {
        stx-weight: uint,
        btc-weight: uint,
        stable-weight: uint,
        is-public: bool
    }
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-portfolio (user principal))
    (ok (map-get? public-portfolios user))
)

;; Check if a portfolio adds up to 100% (10000 basis points)
(define-read-only (is-valid-weight (stx uint) (btc uint) (stable uint))
    (is-eq (+ stx (+ btc stable)) u10000)
)

;; =========================================================
;; Public Functions
;; =========================================================

;; User sets their portfolio structure, allowing it to be cloned if `is-public` is true.
(define-public (set-portfolio-structure (stx uint) (btc uint) (stable uint) (is-public bool))
    (begin
        (asserts! (is-valid-weight stx btc stable) err-invalid-weights)
        (map-set public-portfolios tx-sender {
            stx-weight: stx,
            btc-weight: btc,
            stable-weight: stable,
            is-public: is-public
        })
        (ok true)
    )
)

;; Core Feature: Clone a portfolio
(define-public (clone-portfolio (target-user principal))
    (let (
        (target-portfolio (unwrap! (map-get? public-portfolios target-user) err-no-portfolio))
    )
        ;; Ensure the target has consented to public viewing/cloning
        (asserts! (get is-public target-portfolio) err-private-portfolio)
        
        ;; Clone their exact weight distribution into the sender's own portfolio state
        (map-set public-portfolios tx-sender {
            stx-weight: (get stx-weight target-portfolio),
            btc-weight: (get btc-weight target-portfolio),
            stable-weight: (get stable-weight target-portfolio),
            is-public: false  ;; Cloned portfolios default to private
        })
        
        ;; Note: In a unified mono-repo, you would trigger the rebalancer cross-contract
        ;; (contract-call? .auto-portfolio-rebalancer execute-rebalance ...)
        
        (ok true)
    )
)
