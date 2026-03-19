(define-constant err-no-snapshot (err u500))
(define-constant err-zero-value (err u501))
(define-constant err-no-portfolio (err u502))

(define-constant precision u10000)

(define-map snapshots
    { user: principal, snapshot-id: uint }
    {
        block-height: uint,
        stx-balance: uint,
        btc-balance: uint,
        stable-balance: uint,
        total-value: uint
    }
)

(define-map snapshot-count
    principal
    uint
)

(define-map high-water-mark
    principal
    uint
)

(define-read-only (get-snapshot (user principal) (snapshot-id uint))
    (ok (map-get? snapshots { user: user, snapshot-id: snapshot-id }))
)

(define-read-only (get-snapshot-count (user principal))
    (ok (default-to u0 (map-get? snapshot-count user)))
)

(define-read-only (get-high-water-mark (user principal))
    (ok (default-to u0 (map-get? high-water-mark user)))
)

(define-read-only (calculate-return (user principal) (from-id uint) (to-id uint))
    (let
        (
            (from-snap (map-get? snapshots { user: user, snapshot-id: from-id }))
            (to-snap (map-get? snapshots { user: user, snapshot-id: to-id }))
        )
        (match from-snap
            snap-from
            (match to-snap
                snap-to
                (let
                    (
                        (start-val (get total-value snap-from))
                        (end-val (get total-value snap-to))
                    )
                    (if (is-eq start-val u0)
                        (ok u0)
                        (ok (/ (* (- end-val start-val) precision) start-val))
                    )
                )
                (err err-no-snapshot)
            )
            (err err-no-snapshot)
        )
    )
)

(define-read-only (get-drawdown (user principal))
    (let
        (
            (hwm (default-to u0 (map-get? high-water-mark user)))
            (count (default-to u0 (map-get? snapshot-count user)))
        )
        (if (or (is-eq hwm u0) (is-eq count u0))
            (ok u0)
            (match (map-get? snapshots { user: user, snapshot-id: count })
                latest
                (let
                    (
                        (current-val (get total-value latest))
                    )
                    (if (>= current-val hwm)
                        (ok u0)
                        (ok (/ (* (- hwm current-val) precision) hwm))
                    )
                )
                (ok u0)
            )
        )
    )
)

(define-public (record-snapshot
        (stx-balance uint)
        (btc-balance uint)
        (stable-balance uint)
    )
    (let
        (
            (total (+ (+ stx-balance btc-balance) stable-balance))
            (current-count (default-to u0 (map-get? snapshot-count tx-sender)))
            (new-id (+ current-count u1))
            (current-hwm (default-to u0 (map-get? high-water-mark tx-sender)))
        )
        (asserts! (> total u0) err-zero-value)
        (map-set snapshots { user: tx-sender, snapshot-id: new-id } {
            block-height: stacks-block-height,
            stx-balance: stx-balance,
            btc-balance: btc-balance,
            stable-balance: stable-balance,
            total-value: total
        })
        (map-set snapshot-count tx-sender new-id)
        (if (> total current-hwm)
            (map-set high-water-mark tx-sender total)
            true
        )
        (ok new-id)
    )
)
