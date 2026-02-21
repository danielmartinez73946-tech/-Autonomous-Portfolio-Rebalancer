(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-invalid-fee-rate (err u201))
(define-constant err-no-fees (err u202))
(define-constant err-zero-amount (err u203))

(define-data-var fee-rate uint u50)
(define-data-var total-fees-collected uint u0)

(define-map accumulated-fees
    principal
    uint
)

(define-read-only (get-fee-rate)
    (ok (var-get fee-rate))
)

(define-read-only (get-total-fees-collected)
    (ok (var-get total-fees-collected))
)

(define-read-only (get-accumulated-fees (user principal))
    (ok (default-to u0 (map-get? accumulated-fees user)))
)

(define-read-only (calculate-fee (amount uint))
    (ok (/ (* amount (var-get fee-rate)) u10000))
)

(define-public (set-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u500) err-invalid-fee-rate)
        (var-set fee-rate new-rate)
        (ok true)
    )
)

(define-public (record-fee
        (user principal)
        (fee-amount uint)
    )
    (begin
        (asserts! (> fee-amount u0) err-zero-amount)
        (map-set accumulated-fees user
            (+ (default-to u0 (map-get? accumulated-fees user)) fee-amount)
        )
        (var-set total-fees-collected
            (+ (var-get total-fees-collected) fee-amount)
        )
        (ok true)
    )
)
