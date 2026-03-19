;; auto-compound.clar
;; Feature 10: Auto-Compound Yield Engine
;; Allows users to enroll their portfolio in an auto-compounding service.
;; Keepers or off-chain oracles detect when DeFi yields (e.g., from Stacking) 
;; cross a profitability threshold, trigger a claim, and deposit the 
;; claimed STX directly into the user's active Rebalancer pool.

;; =========================================================
;; Constants
;; =========================================================

(define-constant err-not-enrolled     (err u1800))
(define-constant err-yield-too-low    (err u1801))

;; =========================================================
;; Data Maps
;; =========================================================

;; Tracks user enrollment and auto-compound configuration settings
(define-map compound-enrollment
    principal
    {
        is-active: bool,
        min-claim-threshold: uint,      ;; Minimum yield (uSTX) before triggering a claim
        last-compound-block: uint
    }
)

;; Tracks the historical total yield compounded by each user
(define-map compound-stats
    principal
    uint
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-enrollment-status (user principal))
    (ok (map-get? compound-enrollment user))
)

(define-read-only (get-total-compounded (user principal))
    (default-to u0 (map-get? compound-stats user))
)

;; =========================================================
;; Public Functions
;; =========================================================

;; A user opts-in to the Auto-Compounding protocol engine
(define-public (enroll-auto-compound (min-threshold uint))
    (begin
        (map-set compound-enrollment tx-sender {
            is-active: true,
            min-claim-threshold: min-threshold,
            last-compound-block: stacks-block-height
        })
        (ok true)
    )
)

;; User pauses or opts-out of compounding
(define-public (opt-out-auto-compound)
    (let (
        (profile (unwrap! (map-get? compound-enrollment tx-sender) err-not-enrolled))
    )
        (map-set compound-enrollment tx-sender 
            (merge profile { is-active: false })
        )
        (ok true)
    )
)

;; Triggered by the Protocol / Keepers when yield is detected.
;; It validates the threshold, records the compound, and simulates
;; routing the capital back into the main portfolio.
(define-public (trigger-compound (user principal) (yield-amount uint))
    (let (
        (profile (unwrap! (map-get? compound-enrollment user) err-not-enrolled))
        (historical-yield (get-total-compounded user))
    )
        ;; Must be actively enrolled
        (asserts! (get is-active profile) err-not-enrolled)
        
        ;; Claim amount must exceed user's gas/profit threshold preference
        (asserts! (>= yield-amount (get min-claim-threshold profile)) err-yield-too-low)

        ;; Update enrollment metadata
        (map-set compound-enrollment user 
            (merge profile { last-compound-block: stacks-block-height })
        )

        ;; Update lifetime historical stats
        (map-set compound-stats user (+ historical-yield yield-amount))

        ;; In a fully unified multi-contract protocol, we would now route these funds:
        ;; (contract-call? .auto-portfolio-rebalancer deposit-funds user yield-amount)
        ;; But for this module constraint, we just assert the success natively.
        
        (ok true)
    )
)
