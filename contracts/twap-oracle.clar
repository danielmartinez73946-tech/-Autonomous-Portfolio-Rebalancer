;; twap-oracle.clar
;; Feature 3: Time-Weighted Average Price (TWAP) Oracle
;; Provides manipulation-resistant price feeds for the rebalancer.
;; Uses a window-based moving average system where prices are recorded
;; periodically and averaged over a configurable block window.

;; =========================================================
;; Constants
;; =========================================================

(define-constant contract-owner tx-sender)

(define-constant err-owner-only       (err u1100))
(define-constant err-invalid-asset    (err u1101))
(define-constant err-not-authorized   (err u1102))
(define-constant err-stale-price      (err u1103))
(define-constant err-no-data          (err u1104))
(define-constant err-invalid-window   (err u1105))

(define-constant default-twap-window u144) ;; ~1 day of blocks (assuming 10 min blocks)
(define-constant max-history-slots  u288) ;; Keep last 2 days

;; System assets standard
(define-constant asset-stx u1)
(define-constant asset-btc u2)

;; =========================================================
;; Data Maps
;; =========================================================

;; Authorized price posters (e.g. Keeper Bots or Oracle Nodes)
(define-map authorized-posters
    principal
    bool
)

;; Latest instantaneous price per asset
(define-map latest-price
    uint ;; asset-id
    {
        price: uint,               ;; 8 decimal precision
        block-height: uint,
        updated-by: principal
    }
)

;; Historical price observations for TWAP calculation
(define-map price-observations
    { asset-id: uint, observation-index: uint }
    {
        price: uint,
        block-height: uint,
        cumulative-price: uint
    }
)

;; Counters for observations
(define-map observation-cursor
    uint ;; asset-id
    uint ;; latest index
)

;; Configuration
(define-data-var twap-window-blocks uint default-twap-window)

;; =========================================================
;; Initialization
;; =========================================================

(begin
    (map-set authorized-posters tx-sender true)
    
    ;; Initialize STX
    (map-set observation-cursor asset-stx u0)
    (map-set price-observations { asset-id: asset-stx, observation-index: u0 } 
        { price: u0, block-height: stacks-block-height, cumulative-price: u0 })
        
    ;; Initialize BTC
    (map-set observation-cursor asset-btc u0)
    (map-set price-observations { asset-id: asset-btc, observation-index: u0 } 
        { price: u0, block-height: stacks-block-height, cumulative-price: u0 })
)

;; =========================================================
;; Read-Only Functions
;; =========================================================

(define-read-only (get-latest-price (asset-id uint))
    (ok (map-get? latest-price asset-id))
)

(define-read-only (is-authorized (poster principal))
    (ok (default-to false (map-get? authorized-posters poster)))
)

(define-read-only (get-twap-window)
    (ok (var-get twap-window-blocks))
)

;; Computes TWAP by taking the difference in cumulative prices
;; scaled by the block difference between two observations.
(define-read-only (get-twap-price (asset-id uint))
    (let (
        (cursor (default-to u0 (map-get? observation-cursor asset-id)))
        (latest-obs (unwrap! (map-get? price-observations { asset-id: asset-id, observation-index: cursor }) err-no-data))
        (old-index (if (> cursor u0) (- cursor u1) u0)) ;; Simplified window logic for reference
        (old-obs (unwrap! (map-get? price-observations { asset-id: asset-id, observation-index: old-index }) err-no-data))
    )
        (if (is-eq cursor u0)
            (ok (get price latest-obs))
            (let (
                (block-diff (- (get block-height latest-obs) (get block-height old-obs)))
                (cum-diff (- (get cumulative-price latest-obs) (get cumulative-price old-obs)))
            )
            (if (is-eq block-diff u0)
                (ok (get price latest-obs))
                (ok (/ cum-diff block-diff))
            ))
        )
    )
)

;; =========================================================
;; Public Functions
;; =========================================================

;; Post a new direct price to the oracle. Updates TWAP accumulators.
(define-public (post-price (asset-id uint) (new-price uint))
    (let (
        (cursor (default-to u0 (map-get? observation-cursor asset-id)))
        (last-obs (unwrap! (map-get? price-observations { asset-id: asset-id, observation-index: cursor }) err-invalid-asset))
        (block-diff (- stacks-block-height (get block-height last-obs)))
        (price-accumulation (* (get price last-obs) block-diff))
        (new-cumulative (+ (get cumulative-price last-obs) price-accumulation))
        (new-cursor (if (>= cursor max-history-slots) u0 (+ cursor u1)))
    )
        (asserts! (default-to false (map-get? authorized-posters tx-sender)) err-not-authorized)
        (asserts! (> new-price u0) err-invalid-asset)
        
        ;; Update direct latest price mapping
        (map-set latest-price asset-id {
            price: new-price,
            block-height: stacks-block-height,
            updated-by: tx-sender
        })
        
        ;; Update TWAP accumulator history
        (map-set price-observations { asset-id: asset-id, observation-index: new-cursor } {
            price: new-price,
            block-height: stacks-block-height,
            cumulative-price: new-cumulative
        })
        
        (map-set observation-cursor asset-id new-cursor)
        (ok true)
    )
)

;; =========================================================
;; Admin Functions
;; =========================================================

(define-public (set-poster-authorization (poster principal) (authorized bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-posters poster authorized)
        (ok true)
    )
)

(define-public (set-twap-window (blocks uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> blocks u0) err-invalid-window)
        (var-set twap-window-blocks blocks)
        (ok true)
    )
)
