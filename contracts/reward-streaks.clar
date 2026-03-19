;; reward-streaks.clar
;; Feature 7: Rebalance Streak Rewards
;; Gamifies the portfolio maintenance process by tracking how often users 
;; successfully rebalance (or maintain required portfolio weights).
;; Users who maintain a long streak of rebalances get tiered statuses which
;; can unlock protocol fee discounts or multipliers.

;; =========================================================
;; Constants
;; =========================================================

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized       (err u1500))
(define-constant err-streak-broken      (err u1501))
(define-constant err-too-early          (err u1502))

;; Time constraints (using blocks)
(define-constant blocks-per-day u144)
;; A rebalance must occur within 30 days to keep the streak (approx: 144 * 30 = 4320)
(define-constant max-blocks-between-rebalances u4320)
;; Minimum days between counting a new rebalance towards streak (prevent spam)
(define-constant min-blocks-between-rebalances u144)

;; =========================================================
;; Data Models
;; =========================================================

;; Store each user's streak information
(define-map user-streaks
    principal
    {
        current-streak: uint,          ;; consecutive valid rebalances
        highest-streak: uint,          ;; all-time high score
        last-rebalance-block: uint,    ;; when they last triggered
        tier: uint                     ;; 0=Bronze, 1=Silver, 2=Gold, 3=Diamond
    }
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-user-streak (user principal))
    (ok (map-get? user-streaks user))
)

;; Calculates current tier based on streak count
(define-read-only (calculate-tier (streak uint))
    (if (>= streak u10) u3    ;; Diamond
        (if (>= streak u5) u2 ;; Gold
            (if (>= streak u3) u1 ;; Silver
                u0            ;; Bronze
            )
        )
    )
)

;; Determine if the user's current streak is still alive
(define-read-only (is-streak-alive (user principal))
    (let (
        (record (map-get? user-streaks user))
    )
        (if (is-none record)
            (ok false)
            (let (
                (last-block (get last-rebalance-block (unwrap-panic record)))
                (blocks-passed (- stacks-block-height last-block))
            )
                (if (> blocks-passed max-blocks-between-rebalances)
                    (ok false)
                    (ok true)
                )
            )
        )
    )
)

;; =========================================================
;; Public Functions
;; =========================================================

;; Register a successful rebalance to advance the streak
;; In an orchestrated protocol, this would be guarded by `is-eq tx-sender core-contract`.
;; For this module demo, we allow self-reporting, simulating the rebalance hook.
(define-public (record-rebalance-hook (user principal))
    (let (
        (record (default-to 
                    { current-streak: u0, highest-streak: u0, last-rebalance-block: u0, tier: u0 }
                    (map-get? user-streaks user)))
        (blocks-passed (if (is-eq (get last-rebalance-block record) u0) 
                           max-blocks-between-rebalances 
                           (- stacks-block-height (get last-rebalance-block record))))
        (streak-alive (<= blocks-passed max-blocks-between-rebalances))
    )
        ;; Prevent spamming multiple streak increases in one day
        (asserts! (or (is-eq (get last-rebalance-block record) u0) (>= blocks-passed min-blocks-between-rebalances)) err-too-early)

        (let (
            (new-streak (if streak-alive (+ (get current-streak record) u1) u1))
            (new-high (if (> new-streak (get highest-streak record)) new-streak (get highest-streak record)))
            (new-tier (calculate-tier new-streak))
        )
            (map-set user-streaks user {
                current-streak: new-streak,
                highest-streak: new-high,
                last-rebalance-block: stacks-block-height,
                tier: new-tier
            })
            (ok new-streak)
        )
    )
)

;; If a user's streak naturally expires (missed 30 days), this resets it.
;; Can be called by anyone (Keeper bots) to penalize inactive portfolios.
(define-public (penalize-inactive (user principal))
    (let (
        (record (unwrap! (map-get? user-streaks user) err-streak-broken))
        (blocks-passed (- stacks-block-height (get last-rebalance-block record)))
    )
        (asserts! (> blocks-passed max-blocks-between-rebalances) err-unauthorized)
        
        ;; Reset their current streak and tier, but maintain highest streak history
        (map-set user-streaks user
            (merge record { current-streak: u0, tier: u0 })
        )
        (ok true)
    )
)
