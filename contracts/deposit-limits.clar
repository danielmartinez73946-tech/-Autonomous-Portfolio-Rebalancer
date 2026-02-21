(define-constant err-limit-exceeded (err u800))
(define-constant err-no-limit-set (err u801))
(define-constant err-invalid-limit (err u802))
(define-constant err-zero-amount (err u803))

(define-constant blocks-per-day u144)

(define-map deposit-limits
    principal
    uint
)

(define-map withdrawal-limits
    principal
    uint
)

(define-map daily-deposits
    principal
    {
        amount: uint,
        reset-block: uint
    }
)

(define-map daily-withdrawals
    principal
    {
        amount: uint,
        reset-block: uint
    }
)

(define-read-only (get-deposit-limit (user principal))
    (ok (map-get? deposit-limits user))
)

(define-read-only (get-withdrawal-limit (user principal))
    (ok (map-get? withdrawal-limits user))
)

(define-read-only (get-daily-deposit-used (user principal))
    (match (map-get? daily-deposits user)
        tracker
        (if (>= stacks-block-height (get reset-block tracker))
            (ok u0)
            (ok (get amount tracker))
        )
        (ok u0)
    )
)

(define-read-only (get-daily-withdrawal-used (user principal))
    (match (map-get? daily-withdrawals user)
        tracker
        (if (>= stacks-block-height (get reset-block tracker))
            (ok u0)
            (ok (get amount tracker))
        )
        (ok u0)
    )
)

(define-read-only (check-deposit-allowed (user principal) (amount uint))
    (match (map-get? deposit-limits user)
        limit
        (let
            (
                (used (match (map-get? daily-deposits user)
                    tracker
                    (if (>= stacks-block-height (get reset-block tracker))
                        u0
                        (get amount tracker)
                    )
                    u0
                ))
            )
            (ok (<= (+ used amount) limit))
        )
        (ok true)
    )
)

(define-read-only (check-withdrawal-allowed (user principal) (amount uint))
    (match (map-get? withdrawal-limits user)
        limit
        (let
            (
                (used (match (map-get? daily-withdrawals user)
                    tracker
                    (if (>= stacks-block-height (get reset-block tracker))
                        u0
                        (get amount tracker)
                    )
                    u0
                ))
            )
            (ok (<= (+ used amount) limit))
        )
        (ok true)
    )
)

(define-public (set-deposit-limit (limit uint))
    (begin
        (asserts! (> limit u0) err-invalid-limit)
        (map-set deposit-limits tx-sender limit)
        (ok true)
    )
)

(define-public (set-withdrawal-limit (limit uint))
    (begin
        (asserts! (> limit u0) err-invalid-limit)
        (map-set withdrawal-limits tx-sender limit)
        (ok true)
    )
)

(define-public (remove-deposit-limit)
    (begin
        (asserts! (is-some (map-get? deposit-limits tx-sender)) err-no-limit-set)
        (map-delete deposit-limits tx-sender)
        (ok true)
    )
)

(define-public (remove-withdrawal-limit)
    (begin
        (asserts! (is-some (map-get? withdrawal-limits tx-sender)) err-no-limit-set)
        (map-delete withdrawal-limits tx-sender)
        (ok true)
    )
)

(define-public (record-deposit (user principal) (amount uint))
    (let
        (
            (current (match (map-get? daily-deposits user)
                tracker
                (if (>= stacks-block-height (get reset-block tracker))
                    { amount: u0, reset-block: (+ stacks-block-height blocks-per-day) }
                    tracker
                )
                { amount: u0, reset-block: (+ stacks-block-height blocks-per-day) }
            ))
        )
        (asserts! (> amount u0) err-zero-amount)
        (match (map-get? deposit-limits user)
            limit (asserts! (<= (+ (get amount current) amount) limit) err-limit-exceeded)
            true
        )
        (map-set daily-deposits user {
            amount: (+ (get amount current) amount),
            reset-block: (get reset-block current)
        })
        (ok true)
    )
)

(define-public (record-withdrawal (user principal) (amount uint))
    (let
        (
            (current (match (map-get? daily-withdrawals user)
                tracker
                (if (>= stacks-block-height (get reset-block tracker))
                    { amount: u0, reset-block: (+ stacks-block-height blocks-per-day) }
                    tracker
                )
                { amount: u0, reset-block: (+ stacks-block-height blocks-per-day) }
            ))
        )
        (asserts! (> amount u0) err-zero-amount)
        (match (map-get? withdrawal-limits user)
            limit (asserts! (<= (+ (get amount current) amount) limit) err-limit-exceeded)
            true
        )
        (map-set daily-withdrawals user {
            amount: (+ (get amount current) amount),
            reset-block: (get reset-block current)
        })
        (ok true)
    )
)
