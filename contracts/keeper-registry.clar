(define-constant err-not-authorized (err u300))
(define-constant err-no-portfolio (err u301))
(define-constant err-already-authorized (err u302))
(define-constant err-self-delegation (err u303))

(define-map authorized-keepers
    { user: principal, keeper: principal }
    bool
)

(define-map keeper-count
    principal
    uint
)

(define-read-only (is-authorized-keeper (user principal) (keeper principal))
    (default-to false (map-get? authorized-keepers { user: user, keeper: keeper }))
)

(define-read-only (get-keeper-count (user principal))
    (ok (default-to u0 (map-get? keeper-count user)))
)

(define-public (authorize-keeper (keeper principal))
    (begin
        (asserts! (not (is-eq tx-sender keeper)) err-self-delegation)
        (asserts! (not (is-authorized-keeper tx-sender keeper)) err-already-authorized)
        (map-set authorized-keepers { user: tx-sender, keeper: keeper } true)
        (map-set keeper-count tx-sender
            (+ (default-to u0 (map-get? keeper-count tx-sender)) u1)
        )
        (ok true)
    )
)

(define-public (revoke-keeper (keeper principal))
    (begin
        (asserts! (is-authorized-keeper tx-sender keeper) err-not-authorized)
        (map-delete authorized-keepers { user: tx-sender, keeper: keeper })
        (map-set keeper-count tx-sender
            (- (default-to u0 (map-get? keeper-count tx-sender)) u1)
        )
        (ok true)
    )
)
