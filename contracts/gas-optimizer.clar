;; gas-optimizer.clar
;; Feature 5: Scheduled Rebalance Gas Estimator
;; Allows users to define a maximum acceptable gas fee threshold for rebalances.
;; Keepers simulating the execution will check this contract before sending the tx.
;; If current network congestion makes the fee too high, the rebalance is deferred.

;; =========================================================
;; Constants
;; =========================================================

(define-constant contract-owner tx-sender)

(define-constant err-unauthorized       (err u1300))
(define-constant err-no-threshold       (err u1301))
(define-constant err-gas-too-high       (err u1302))

;; =========================================================
;; Data Maps
;; =========================================================

;; Store the maximum micro-STX user is willing to pay for a rebalance
(define-map max-gas-thresholds
    principal     ;; User's portfolio address
    uint          ;; Max gas fee in micro-STX (e.g. 50000)
)

;; Store average recent gas prices (updated by keepers/oracle)
;; Used as an on-chain reference of network congestion
(define-data-var current-network-gas-base uint u1) ;; Base fee per byte/computation

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-user-threshold (user principal))
    (ok (map-get? max-gas-thresholds user))
)

(define-read-only (get-network-base-fee)
    (ok (var-get current-network-gas-base))
)

;; Estimate the cost of a standard rebalance transaction
;; Hardcoded approx weight for standard rebalance = 12500 units
(define-read-only (estimate-rebalance-cost)
    (ok (* (var-get current-network-gas-base) u12500))
)

;; Check if a user's threshold permits the rebalance AT CURRENT network conditions
(define-read-only (is-rebalance-profitable (user principal))
    (let (
        (threshold (unwrap! (map-get? max-gas-thresholds user) err-no-threshold))
        (est-cost (unwrap-panic (estimate-rebalance-cost)))
    )
        (ok (<= est-cost threshold))
    )
)

;; =========================================================
;; Public Functions
;; =========================================================

;; User sets their maximum willingness to pay for gas
(define-public (set-gas-threshold (max-fee-ustx uint))
    (begin
        (map-set max-gas-thresholds tx-sender max-fee-ustx)
        (ok true)
    )
)

;; User removes their gas threshold preference (default to always rebalance)
(define-public (remove-gas-threshold)
    (begin
        (map-delete max-gas-thresholds tx-sender)
        (ok true)
    )
)

;; Wraps the rebalance logic with a gas limit check
;; (In a unified system, this would call the portfolio rebalancer)
(define-public (conditionally-rebalance)
    (let (
        (user tx-sender)
        (threshold (map-get? max-gas-thresholds user))
        (est-cost (unwrap-panic (estimate-rebalance-cost)))
    )
        ;; If they have a threshold, ensure estimated cost doesn't exceed it
        (if (is-some threshold)
            (asserts! (<= est-cost (unwrap-panic threshold)) err-gas-too-high)
            true
        )
        
        ;; Would insert cross-contract call to auto-portfolio-rebalancer here
        ;; (contract-call? .auto-portfolio-rebalancer execute-rebalance ...)
        
        (ok true)
    )
)

;; =========================================================
;; Admin Functions (Oracle / Keepers)
;; =========================================================

;; Keepers update the rolling average base fee of the network
(define-public (update-network-base-fee (new-base-fee uint))
    (begin
        ;; simplified: in production requires auth check
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set current-network-gas-base new-base-fee)
        (ok true)
    )
)
