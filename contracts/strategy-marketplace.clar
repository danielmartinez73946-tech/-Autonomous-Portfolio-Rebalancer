;; strategy-marketplace.clar
;; Feature 4: Public Strategy Marketplace
;; Allows portfolio managers to publish their strategies.
;; Users can subscribe to premium strategies for a fee, which is split
;; between the strategy creator and the protocol treasury.

;; =========================================================
;; Constants
;; =========================================================

(define-constant contract-owner tx-sender)

(define-constant err-owner-only       (err u1200))
(define-constant err-not-found        (err u1201))
(define-constant err-unauthorized     (err u1202))
(define-constant err-already-listed   (err u1203))
(define-constant err-insufficient-fee (err u1204))
(define-constant err-already-subbed   (err u1205))

;; Protocol fee percentage (e.g. 100 = 1%) - base 10000
(define-data-var protocol-fee-percent uint u100)
(define-data-var protocol-treasury principal tx-sender)

;; =========================================================
;; Data Maps
;; =========================================================

;; Store published strategies
(define-map marketplace-listings
    { publisher: principal, strategy-id: uint }
        {
            price: uint,            ;; Subscription fee in uSTX
            active: bool,           ;; Is listing currently active
            subscribers-count: uint,
            total-earned: uint
        }
)

;; Track user subscriptions
(define-map strategy-subscriptions
    { subscriber: principal, publisher: principal, strategy-id: uint }
    {
        subscribed-at: uint,
        active: bool
    }
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-listing (publisher principal) (strategy-id uint))
    (ok (map-get? marketplace-listings { publisher: publisher, strategy-id: strategy-id }))
)

(define-read-only (is-subscribed (subscriber principal) (publisher principal) (strategy-id uint))
    (let (
        (sub-data (map-get? strategy-subscriptions { subscriber: subscriber, publisher: publisher, strategy-id: strategy-id }))
    )
        (if (is-some sub-data)
            (ok (get active (unwrap-panic sub-data)))
            (ok false)
        )
    )
)

(define-read-only (get-protocol-config)
    (ok {
        fee-percent: (var-get protocol-fee-percent),
        treasury: (var-get protocol-treasury)
    })
)

;; =========================================================
;; Public Functions
;; =========================================================

;; Publish a strategy to the marketplace
(define-public (list-strategy (strategy-id uint) (price uint))
    (let (
        (listing-key { publisher: tx-sender, strategy-id: strategy-id })
        (existing (map-get? marketplace-listings listing-key))
    )
        ;; Note: In a fully integrated system, this would call strategy-registry to verify ownership.
        ;; For independent module architecture, we trust the publisher parameter here.
        (asserts! (is-none existing) err-already-listed)
        
        (map-set marketplace-listings listing-key {
            price: price,
            active: true,
            subscribers-count: u0,
            total-earned: u0
        })
        (ok true)
    )
)

;; Update the price or status of a listing
(define-public (update-listing (strategy-id uint) (new-price uint) (active bool))
    (let (
        (listing-key { publisher: tx-sender, strategy-id: strategy-id })
        (listing (unwrap! (map-get? marketplace-listings listing-key) err-not-found))
    )
        (map-set marketplace-listings listing-key
            (merge listing { price: new-price, active: active })
        )
        (ok true)
    )
)

;; Subscribe to a public strategy
(define-public (subscribe (publisher principal) (strategy-id uint))
    (let (
        (listing-key { publisher: publisher, strategy-id: strategy-id })
        (sub-key { subscriber: tx-sender, publisher: publisher, strategy-id: strategy-id })
        (listing (unwrap! (map-get? marketplace-listings listing-key) err-not-found))
        (existing-sub (map-get? strategy-subscriptions sub-key))
        (price (get price listing))
        (protocol-cut (/ (* price (var-get protocol-fee-percent)) u10000))
        (publisher-cut (- price protocol-cut))
    )
        (asserts! (get active listing) err-not-found)
        (asserts! (not (default-to false (get active existing-sub))) err-already-subbed)
        
        ;; Handle payments if price > 0
        (if (> price u0)
            (begin
                (try! (stx-transfer? publisher-cut tx-sender publisher))
                (if (> protocol-cut u0)
                    (try! (stx-transfer? protocol-cut tx-sender (var-get protocol-treasury)))
                    true
                )
            )
            true
        )
        
        ;; Update Subscription
        (map-set strategy-subscriptions sub-key {
            subscribed-at: stacks-block-height,
            active: true
        })

        ;; Update Listing Stats
        (map-set marketplace-listings listing-key
            (merge listing {
                subscribers-count: (+ (get subscribers-count listing) u1),
                total-earned: (+ (get total-earned listing) publisher-cut)
            })
        )
        
        (ok true)
    )
)

;; =========================================================
;; Admin Functions
;; =========================================================

(define-public (set-protocol-fee (new-fee-percent uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        ;; Prevent excessive fees (max 20%)
        (asserts! (<= new-fee-percent u2000) err-unauthorized)
        (var-set protocol-fee-percent new-fee-percent)
        (ok true)
    )
)

(define-public (set-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set protocol-treasury new-treasury)
        (ok true)
    )
)
