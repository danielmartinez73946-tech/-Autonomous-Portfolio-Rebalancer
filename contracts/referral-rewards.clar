;; referral-rewards.clar
;; Feature: Referral Rewards System
;; Users can register a referrer when creating a portfolio.
;; When a referred user completes their first rebalance,
;; both the referrer and the referee earn bonus reward points.
;; Reward points can be queried and redeemed by the contract owner
;; for off-chain incentives or future on-chain integrations.

;; =========================================================
;; Constants
;; =========================================================

(define-constant contract-owner tx-sender)

(define-constant err-owner-only             (err u700))
(define-constant err-already-referred       (err u701))
(define-constant err-self-referral          (err u702))
(define-constant err-no-referral            (err u703))
(define-constant err-already-redeemed       (err u704))
(define-constant err-zero-points            (err u705))
(define-constant err-invalid-bonus          (err u706))

;; Default reward points awarded to referrer and referee
(define-data-var referrer-bonus  uint u50)
(define-data-var referee-bonus   uint u25)

;; =========================================================
;; Data Maps
;; =========================================================

;; Tracks who referred whom
(define-map referrals
    principal   ;; referee (new user)
    principal   ;; referrer
)

;; Tracks accumulated reward points per user
(define-map reward-points
    principal
    uint
)

;; Tracks whether the first-rebalance bonus has been issued
(define-map first-rebalance-rewarded
    principal   ;; referee
    bool
)

;; Tracks total redemptions per user (informational)
(define-map total-redeemed
    principal
    uint
)

;; Global stats
(define-data-var total-referrals   uint u0)
(define-data-var total-rewards-issued uint u0)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-referrer (referee principal))
    (ok (map-get? referrals referee))
)

(define-read-only (get-reward-points (user principal))
    (ok (default-to u0 (map-get? reward-points user)))
)

(define-read-only (has-been-rewarded (referee principal))
    (ok (default-to false (map-get? first-rebalance-rewarded referee)))
)

(define-read-only (get-total-redeemed (user principal))
    (ok (default-to u0 (map-get? total-redeemed user)))
)

(define-read-only (get-bonus-config)
    (ok {
        referrer-bonus: (var-get referrer-bonus),
        referee-bonus:  (var-get referee-bonus),
    })
)

(define-read-only (get-global-stats)
    (ok {
        total-referrals:     (var-get total-referrals),
        total-rewards-issued: (var-get total-rewards-issued),
    })
)

;; =========================================================
;; Public Functions
;; =========================================================

;; Called by a new user to register who referred them.
;; Must be called before completing the first rebalance.
(define-public (register-referral (referrer principal))
    (begin
        (asserts! (not (is-eq tx-sender referrer)) err-self-referral)
        (asserts! (is-none (map-get? referrals tx-sender)) err-already-referred)
        (map-set referrals tx-sender referrer)
        (var-set total-referrals (+ (var-get total-referrals) u1))
        (ok true)
    )
)

;; Called after a referred user completes their first rebalance.
;; Awards points to both the referrer and the referee.
;; Idempotent: only rewards once per referee.
(define-public (claim-first-rebalance-bonus)
    (let (
        (referrer (unwrap! (map-get? referrals tx-sender) err-no-referral))
        (already-rewarded (default-to false (map-get? first-rebalance-rewarded tx-sender)))
        (ref-bonus  (var-get referrer-bonus))
        (ref2-bonus (var-get referee-bonus))
        (referrer-current (default-to u0 (map-get? reward-points referrer)))
        (referee-current  (default-to u0 (map-get? reward-points tx-sender)))
    )
        (asserts! (not already-rewarded) err-already-redeemed)
        ;; Mark as rewarded
        (map-set first-rebalance-rewarded tx-sender true)
        ;; Grant points to referrer
        (map-set reward-points referrer (+ referrer-current ref-bonus))
        ;; Grant points to referee
        (map-set reward-points tx-sender (+ referee-current ref2-bonus))
        ;; Update global counter
        (var-set total-rewards-issued (+ (var-get total-rewards-issued) (+ ref-bonus ref2-bonus)))
        (ok true)
    )
)

;; Allows a user to redeem (burn) their reward points.
;; Actual off-chain incentive delivery is handled by the protocol backend.
(define-public (redeem-points (amount uint))
    (let (
        (current (default-to u0 (map-get? reward-points tx-sender)))
        (redeemed-so-far (default-to u0 (map-get? total-redeemed tx-sender)))
    )
        (asserts! (> amount u0) err-zero-points)
        (asserts! (>= current amount) err-zero-points)
        (map-set reward-points tx-sender (- current amount))
        (map-set total-redeemed tx-sender (+ redeemed-so-far amount))
        (ok true)
    )
)

;; =========================================================
;; Owner-Only Admin Functions
;; =========================================================

;; Update the referrer bonus points amount
(define-public (set-referrer-bonus (new-bonus uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-bonus u0) err-invalid-bonus)
        (var-set referrer-bonus new-bonus)
        (ok true)
    )
)

;; Update the referee bonus points amount
(define-public (set-referee-bonus (new-bonus uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-bonus u0) err-invalid-bonus)
        (var-set referee-bonus new-bonus)
        (ok true)
    )
)

;; Owner can grant bonus points manually (e.g. for campaigns)
(define-public (grant-bonus-points (user principal) (amount uint))
    (let (
        (current (default-to u0 (map-get? reward-points user)))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-bonus)
        (map-set reward-points user (+ current amount))
        (var-set total-rewards-issued (+ (var-get total-rewards-issued) amount))
        (ok true)
    )
)
