(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-allocation (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-not-rebalance-time (err u103))
(define-constant err-no-portfolio (err u104))
(define-constant err-already-initialized (err u105))
(define-constant err-zero-amount (err u106))
(define-constant err-invalid-asset (err u107))
(define-constant err-drift-not-exceeded (err u108))

(define-constant blocks-per-quarter u4320)
(define-constant precision u10000)
(define-constant max-allocation u100)

(define-constant asset-stx u1)
(define-constant asset-btc u2)
(define-constant asset-stable u3)

(define-map portfolios
    principal
    {
        stx-balance: uint,
        btc-balance: uint,
        stable-balance: uint,
        stx-target: uint,
        btc-target: uint,
        stable-target: uint,
        last-rebalance: uint,
        initialized: bool
    }
)

(define-map rebalance-history
    { user: principal, timestamp: uint }
    {
        stx-before: uint,
        btc-before: uint,
        stable-before: uint,
        stx-after: uint,
        btc-after: uint,
        stable-after: uint
    }
)

(define-map drift-thresholds
    principal
    uint
)

(define-data-var total-portfolios uint u0)
(define-data-var rebalance-count uint u0)

(define-read-only (get-portfolio (user principal))
    (ok (map-get? portfolios user))
)

(define-read-only (get-total-value (user principal))
    (match (map-get? portfolios user)
        portfolio (ok (+ (+ (get stx-balance portfolio) (get btc-balance portfolio)) (get stable-balance portfolio)))
        (err err-no-portfolio)
    )
)

(define-read-only (get-current-allocation (user principal))
    (match (map-get? portfolios user)
        portfolio
        (let
            (
                (total (+ (+ (get stx-balance portfolio) (get btc-balance portfolio)) (get stable-balance portfolio)))
            )
            (if (is-eq total u0)
                (ok { stx-pct: u0, btc-pct: u0, stable-pct: u0 })
                (ok {
                    stx-pct: (/ (* (get stx-balance portfolio) precision) total),
                    btc-pct: (/ (* (get btc-balance portfolio) precision) total),
                    stable-pct: (/ (* (get stable-balance portfolio) precision) total)
                })
            )
        )
        (err err-no-portfolio)
    )
)

(define-read-only (can-rebalance (user principal))
    (match (map-get? portfolios user)
        portfolio
        (ok (>= (- stacks-block-height (get last-rebalance portfolio)) blocks-per-quarter))
        (err err-no-portfolio)
    )
)

(define-read-only (calculate-rebalance-needs (user principal))
    (match (map-get? portfolios user)
        portfolio
        (let
            (
                (total (+ (+ (get stx-balance portfolio) (get btc-balance portfolio)) (get stable-balance portfolio)))
                (target-stx (/ (* total (get stx-target portfolio)) max-allocation))
                (target-btc (/ (* total (get btc-target portfolio)) max-allocation))
                (target-stable (/ (* total (get stable-target portfolio)) max-allocation))
            )
            (ok {
                stx-delta: (if (> target-stx (get stx-balance portfolio))
                    (- target-stx (get stx-balance portfolio))
                    u0),
                btc-delta: (if (> target-btc (get btc-balance portfolio))
                    (- target-btc (get btc-balance portfolio))
                    u0),
                stable-delta: (if (> target-stable (get stable-balance portfolio))
                    (- target-stable (get stable-balance portfolio))
                    u0),
                stx-excess: (if (< target-stx (get stx-balance portfolio))
                    (- (get stx-balance portfolio) target-stx)
                    u0),
                btc-excess: (if (< target-btc (get btc-balance portfolio))
                    (- (get btc-balance portfolio) target-btc)
                    u0),
                stable-excess: (if (< target-stable (get stable-balance portfolio))
                    (- (get stable-balance portfolio) target-stable)
                    u0)
            })
        )
        (err err-no-portfolio)
    )
)

(define-public (initialize-portfolio (stx-target uint) (btc-target uint) (stable-target uint))
    (let
        (
            (portfolio-data (map-get? portfolios tx-sender))
        )
        (asserts! (is-none portfolio-data) err-already-initialized)
        (asserts! (is-eq (+ (+ stx-target btc-target) stable-target) max-allocation) err-invalid-allocation)
        (asserts! (and (> stx-target u0) (and (> btc-target u0) (> stable-target u0))) err-invalid-allocation)
        (map-set portfolios tx-sender {
            stx-balance: u0,
            btc-balance: u0,
            stable-balance: u0,
            stx-target: stx-target,
            btc-target: btc-target,
            stable-target: stable-target,
            last-rebalance: stacks-block-height,
            initialized: true
        })
        (var-set total-portfolios (+ (var-get total-portfolios) u1))
        (ok true)
    )
)

(define-public (update-targets (stx-target uint) (btc-target uint) (stable-target uint))
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-no-portfolio))
        )
        (asserts! (is-eq (+ (+ stx-target btc-target) stable-target) max-allocation) err-invalid-allocation)
        (asserts! (and (> stx-target u0) (and (> btc-target u0) (> stable-target u0))) err-invalid-allocation)
        (map-set portfolios tx-sender (merge portfolio {
            stx-target: stx-target,
            btc-target: btc-target,
            stable-target: stable-target
        }))
        (ok true)
    )
)

(define-public (deposit (asset-type uint) (amount uint))
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-no-portfolio))
        )
        (asserts! (> amount u0) err-zero-amount)
        (asserts! (or (is-eq asset-type asset-stx) (or (is-eq asset-type asset-btc) (is-eq asset-type asset-stable))) err-invalid-asset)
        (if (is-eq asset-type asset-stx)
            (map-set portfolios tx-sender (merge portfolio { stx-balance: (+ (get stx-balance portfolio) amount) }))
            (if (is-eq asset-type asset-btc)
                (map-set portfolios tx-sender (merge portfolio { btc-balance: (+ (get btc-balance portfolio) amount) }))
                (map-set portfolios tx-sender (merge portfolio { stable-balance: (+ (get stable-balance portfolio) amount) }))
            )
        )
        (ok true)
    )
)

(define-public (withdraw (asset-type uint) (amount uint))
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-no-portfolio))
        )
        (asserts! (> amount u0) err-zero-amount)
        (asserts! (or (is-eq asset-type asset-stx) (or (is-eq asset-type asset-btc) (is-eq asset-type asset-stable))) err-invalid-asset)
        (if (is-eq asset-type asset-stx)
            (begin
                (asserts! (>= (get stx-balance portfolio) amount) err-insufficient-balance)
                (map-set portfolios tx-sender (merge portfolio { stx-balance: (- (get stx-balance portfolio) amount) }))
            )
            (if (is-eq asset-type asset-btc)
                (begin
                    (asserts! (>= (get btc-balance portfolio) amount) err-insufficient-balance)
                    (map-set portfolios tx-sender (merge portfolio { btc-balance: (- (get btc-balance portfolio) amount) }))
                )
                (begin
                    (asserts! (>= (get stable-balance portfolio) amount) err-insufficient-balance)
                    (map-set portfolios tx-sender (merge portfolio { stable-balance: (- (get stable-balance portfolio) amount) }))
                )
            )
        )
        (ok true)
    )
)

(define-public (execute-rebalance)
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-no-portfolio))
            (total (+ (+ (get stx-balance portfolio) (get btc-balance portfolio)) (get stable-balance portfolio)))
            (target-stx (/ (* total (get stx-target portfolio)) max-allocation))
            (target-btc (/ (* total (get btc-target portfolio)) max-allocation))
            (target-stable (/ (* total (get stable-target portfolio)) max-allocation))
        )
        (asserts! (>= (- stacks-block-height (get last-rebalance portfolio)) blocks-per-quarter) err-not-rebalance-time)
        (map-set rebalance-history 
            { user: tx-sender, timestamp: stacks-block-height }
            {
                stx-before: (get stx-balance portfolio),
                btc-before: (get btc-balance portfolio),
                stable-before: (get stable-balance portfolio),
                stx-after: target-stx,
                btc-after: target-btc,
                stable-after: target-stable
            }
        )
        (map-set portfolios tx-sender (merge portfolio {
            stx-balance: target-stx,
            btc-balance: target-btc,
            stable-balance: target-stable,
            last-rebalance: stacks-block-height
        }))
        (var-set rebalance-count (+ (var-get rebalance-count) u1))
        (ok true)
    )
)

(define-read-only (get-stats)
    (ok {
        total-portfolios: (var-get total-portfolios),
        rebalance-count: (var-get rebalance-count)
    })
)

(define-read-only (get-rebalance-history (user principal) (timestamp uint))
    (ok (map-get? rebalance-history { user: user, timestamp: timestamp }))
)

(define-read-only (get-drift-threshold (user principal))
    (ok (map-get? drift-thresholds user))
)

(define-read-only (get-max-drift (user principal))
    (match (map-get? portfolios user)
        portfolio
        (let
            (
                (total (+ (+ (get stx-balance portfolio) (get btc-balance portfolio)) (get stable-balance portfolio)))
                (stx-current-pct (if (is-eq total u0) u0 (/ (* (get stx-balance portfolio) precision) total)))
                (btc-current-pct (if (is-eq total u0) u0 (/ (* (get btc-balance portfolio) precision) total)))
                (stable-current-pct (if (is-eq total u0) u0 (/ (* (get stable-balance portfolio) precision) total)))
                (stx-target-pct (/ (* (get stx-target portfolio) precision) max-allocation))
                (btc-target-pct (/ (* (get btc-target portfolio) precision) max-allocation))
                (stable-target-pct (/ (* (get stable-target portfolio) precision) max-allocation))
                (stx-drift (if (> stx-current-pct stx-target-pct) (- stx-current-pct stx-target-pct) (- stx-target-pct stx-current-pct)))
                (btc-drift (if (> btc-current-pct btc-target-pct) (- btc-current-pct btc-target-pct) (- btc-target-pct btc-current-pct)))
                (stable-drift (if (> stable-current-pct stable-target-pct) (- stable-current-pct stable-target-pct) (- stable-target-pct stable-current-pct)))
                (max-drift-val (if (> stx-drift btc-drift) (if (> stx-drift stable-drift) stx-drift stable-drift) (if (> btc-drift stable-drift) btc-drift stable-drift)))
            )
            (ok max-drift-val)
        )
        (err err-no-portfolio)
    )
)

(define-public (set-drift-threshold (threshold uint))
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-no-portfolio))
        )
        (map-set drift-thresholds tx-sender threshold)
        (ok true)
    )
)

(define-public (execute-volatility-rebalance)
    (let
        (
            (portfolio (unwrap! (map-get? portfolios tx-sender) err-no-portfolio))
            (threshold (unwrap! (map-get? drift-thresholds tx-sender) err-drift-not-exceeded))
            (max-drift (unwrap! (get-max-drift tx-sender) err-no-portfolio))
            (total (+ (+ (get stx-balance portfolio) (get btc-balance portfolio)) (get stable-balance portfolio)))
            (target-stx (/ (* total (get stx-target portfolio)) max-allocation))
            (target-btc (/ (* total (get btc-target portfolio)) max-allocation))
            (target-stable (/ (* total (get stable-target portfolio)) max-allocation))
        )
        (asserts! (>= max-drift threshold) err-drift-not-exceeded)
        (map-set rebalance-history 
            { user: tx-sender, timestamp: stacks-block-height }
            {
                stx-before: (get stx-balance portfolio),
                btc-before: (get btc-balance portfolio),
                stable-before: (get stable-balance portfolio),
                stx-after: target-stx,
                btc-after: target-btc,
                stable-after: target-stable
            }
        )
        (map-set portfolios tx-sender (merge portfolio {
            stx-balance: target-stx,
            btc-balance: target-btc,
            stable-balance: target-stable,
            last-rebalance: stacks-block-height
        }))
        (var-set rebalance-count (+ (var-get rebalance-count) u1))
        (ok true)
    )
)