;; multi-wallet-guardian.clar
;; Feature 6: Multi-Wallet Guardian System
;; Provides a decentralized 2FA and fallback recovery system for portfolios.
;; Users assign a 'Guardian' (e.g. cold storage or trusted entity).
;; Guardians can pause automated rebalancing if they detect anomalies,
;; and trigger an emergency exit, pulling funds safely back to the owner or guardian address.

;; =========================================================
;; Constants
;; =========================================================

(define-constant err-no-guardian      (err u1400))
(define-constant err-unauthorized     (err u1401))
(define-constant err-already-locked   (err u1402))
(define-constant err-not-locked       (err u1403))

;; =========================================================
;; Data Maps
;; =========================================================

;; Store the principal address of the guardian
(define-map guardians
    principal     ;; Primary Account
    principal     ;; Guardian Account
)

;; Store the lock status of the primary account
(define-map portfolio-locks
    principal     ;; Primary Account
    bool          ;; Locked status (true = paused)
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-guardian (user principal))
    (ok (map-get? guardians user))
)

(define-read-only (is-portfolio-locked (user principal))
    (ok (default-to false (map-get? portfolio-locks user)))
)

;; Contract check verifying if the caller is the registered guardian for a user
(define-read-only (is-guardian-for (user principal) (caller principal))
    (let (
        (assigned-guardian (map-get? guardians user))
    )
        (ok (and (is-some assigned-guardian) (is-eq (unwrap-panic assigned-guardian) caller)))
    )
)

;; =========================================================
;; Public Functions
;; =========================================================

;; Primary account registers a new Guardian
(define-public (set-guardian (guardian-address principal))
    (begin
        (map-set guardians tx-sender guardian-address)
        (ok true)
    )
)

;; Primary account removes their Guardian
(define-public (remove-guardian)
    (begin
        (map-delete guardians tx-sender)
        (ok true)
    )
)

;; Guardian pauses all autonomous rebalancing for the Primary account
(define-public (guardian-lock (primary-user principal))
    (let (
        (is-authorized (unwrap-panic (is-guardian-for primary-user tx-sender)))
        (current-lock (default-to false (map-get? portfolio-locks primary-user)))
    )
        (asserts! is-authorized err-unauthorized)
        (asserts! (not current-lock) err-already-locked)
        
        (map-set portfolio-locks primary-user true)
        (ok true)
    )
)

;; Guardian OR Primary account can unlock the portfolio
(define-public (unlock-portfolio (primary-user principal))
    (let (
        (is-authorized (or (is-eq tx-sender primary-user) (unwrap-panic (is-guardian-for primary-user tx-sender))))
        (current-lock (default-to false (map-get? portfolio-locks primary-user)))
    )
        (asserts! is-authorized err-unauthorized)
        (asserts! current-lock err-not-locked)
        
        (map-set portfolio-locks primary-user false)
        (ok true)
    )
)

;; An example of how Guardian might trigger an emergency system-exit.
;; In a fully deployed monolithic approach, this would utilize (contract-call?) 
;; to the core `auto-portfolio-rebalancer` to force an emergency withdrawal
;; of all stablecoins/assets back to the primary user's pure STX address.
(define-public (guardian-emergency-recovery (primary-user principal))
    (let (
        (is-authorized (unwrap-panic (is-guardian-for primary-user tx-sender)))
    )
        (asserts! is-authorized err-unauthorized)
        ;; Automatically locks trading
        (map-set portfolio-locks primary-user true)
        
        ;; Would insert cross-contract orchestrations here:
        ;; (contract-call? .auto-portfolio-rebalancer force-exit primary-user)
        
        (ok true)
    )
)
