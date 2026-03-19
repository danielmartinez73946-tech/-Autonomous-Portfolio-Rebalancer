;; asset-whitelist.clar
;; Feature 2: Asset Whitelist / Blacklist System
;; Provides a centralized registry for protocol-approved assets.
;; Strategies and auto-rebalancers can query this to ensure they
;; only trade and hold approved assets, protecting users from malicious tokens.

;; =========================================================
;; Constants
;; =========================================================

(define-constant contract-owner tx-sender)

(define-constant err-owner-only       (err u800))
(define-constant err-already-listed   (err u801))
(define-constant err-not-listed       (err u802))

;; Define system asset IDs for backwards compatibility (Matches auto-portfolio-rebalancer definitions)
(define-constant asset-stx u1)
(define-constant asset-btc u2)
(define-constant asset-stable u3)

;; =========================================================
;; Data Maps
;; =========================================================

;; Tracks whitelisted assets by principal (Token Contract Address)
(define-map whitelisted-assets
    principal
    {
        added-by: principal,
        added-at: uint,
        is-active: bool,
        name: (string-ascii 32)
    }
)

;; Tracks standard protocol assets by internal ID 
(define-map standard-assets
    uint 
    bool
)

;; =========================================================
;; Initialization
;; =========================================================

;; Pre-approve core assets
(begin
    (map-set standard-assets asset-stx true)
    (map-set standard-assets asset-btc true)
    (map-set standard-assets asset-stable true)
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

;; Check if an external token contract is whitelisted
(define-read-only (is-whitelisted (asset-contract principal))
    (let (
        (asset-data (map-get? whitelisted-assets asset-contract))
    )
        (if (is-some asset-data)
            (ok (get is-active (unwrap-panic asset-data)))
            (ok false)
        )
    )
)

;; Check standard protocol internal asset ID
(define-read-only (is-standard-asset-allowed (asset-id uint))
    (ok (default-to false (map-get? standard-assets asset-id)))
)

;; Retrieve token details
(define-read-only (get-asset-details (asset-contract principal))
    (ok (map-get? whitelisted-assets asset-contract))
)

;; =========================================================
;; Public Functions (Admin Only)
;; =========================================================

;; Add a brand new asset to the whitelist
(define-public (add-asset (asset-contract principal) (name (string-ascii 32)))
    (let (
        (existing-entry (map-get? whitelisted-assets asset-contract))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none existing-entry) err-already-listed)
        
        (map-set whitelisted-assets asset-contract {
            added-by: tx-sender,
            added-at: stacks-block-height,
            is-active: true,
            name: name
        })
        (ok true)
    )
)

;; Completely suspend an asset (Blacklist)
(define-public (suspend-asset (asset-contract principal))
    (let (
        (asset-data (unwrap! (map-get? whitelisted-assets asset-contract) err-not-listed))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set whitelisted-assets asset-contract 
            (merge asset-data { is-active: false })
        )
        (ok true)
    )
)

;; Reactivate an asset that was previously suspended
(define-public (reactivate-asset (asset-contract principal))
    (let (
        (asset-data (unwrap! (map-get? whitelisted-assets asset-contract) err-not-listed))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set whitelisted-assets asset-contract 
            (merge asset-data { is-active: true })
        )
        (ok true)
    )
)

;; Allows suspending the core internal assets in an emergency
(define-public (set-standard-asset-status (asset-id uint) (status bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set standard-assets asset-id status)
        (ok true)
    )
)
