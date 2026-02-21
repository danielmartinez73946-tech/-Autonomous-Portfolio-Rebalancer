(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u900))
(define-constant err-zero-value (err u901))

(define-constant epoch-length u4320)

(define-data-var total-value-locked uint u0)
(define-data-var total-users uint u0)
(define-data-var total-rebalances uint u0)
(define-data-var total-deposits uint u0)
(define-data-var total-withdrawals uint u0)
(define-data-var current-epoch uint u1)

(define-map user-registered principal bool)

(define-map epoch-stats
    uint
    {
        rebalances: uint,
        deposits: uint,
        withdrawals: uint,
        start-block: uint
    }
)

(define-map user-activity
    principal
    {
        total-rebalances: uint,
        total-deposited: uint,
        total-withdrawn: uint,
        last-active-block: uint
    }
)

(begin
    (map-set epoch-stats u1 {
        rebalances: u0,
        deposits: u0,
        withdrawals: u0,
        start-block: stacks-block-height
    })
)

(define-read-only (get-protocol-summary)
    (ok {
        tvl: (var-get total-value-locked),
        users: (var-get total-users),
        rebalances: (var-get total-rebalances),
        deposits: (var-get total-deposits),
        withdrawals: (var-get total-withdrawals),
        epoch: (var-get current-epoch)
    })
)

(define-read-only (get-epoch-stats (epoch-id uint))
    (ok (map-get? epoch-stats epoch-id))
)

(define-read-only (get-user-activity (user principal))
    (ok (map-get? user-activity user))
)

(define-read-only (get-current-epoch)
    (ok (var-get current-epoch))
)

(define-public (record-rebalance (user principal))
    (let
        (
            (epoch (var-get current-epoch))
            (activity (default-to
                { total-rebalances: u0, total-deposited: u0, total-withdrawn: u0, last-active-block: u0 }
                (map-get? user-activity user)
            ))
            (stats (default-to
                { rebalances: u0, deposits: u0, withdrawals: u0, start-block: stacks-block-height }
                (map-get? epoch-stats epoch)
            ))
        )
        (if (not (default-to false (map-get? user-registered user)))
            (begin
                (map-set user-registered user true)
                (var-set total-users (+ (var-get total-users) u1))
            )
            true
        )
        (var-set total-rebalances (+ (var-get total-rebalances) u1))
        (map-set user-activity user
            (merge activity {
                total-rebalances: (+ (get total-rebalances activity) u1),
                last-active-block: stacks-block-height
            })
        )
        (map-set epoch-stats epoch
            (merge stats {
                rebalances: (+ (get rebalances stats) u1)
            })
        )
        (ok true)
    )
)

(define-public (record-deposit (user principal) (amount uint))
    (let
        (
            (epoch (var-get current-epoch))
            (activity (default-to
                { total-rebalances: u0, total-deposited: u0, total-withdrawn: u0, last-active-block: u0 }
                (map-get? user-activity user)
            ))
            (stats (default-to
                { rebalances: u0, deposits: u0, withdrawals: u0, start-block: stacks-block-height }
                (map-get? epoch-stats epoch)
            ))
        )
        (asserts! (> amount u0) err-zero-value)
        (if (not (default-to false (map-get? user-registered user)))
            (begin
                (map-set user-registered user true)
                (var-set total-users (+ (var-get total-users) u1))
            )
            true
        )
        (var-set total-deposits (+ (var-get total-deposits) amount))
        (var-set total-value-locked (+ (var-get total-value-locked) amount))
        (map-set user-activity user
            (merge activity {
                total-deposited: (+ (get total-deposited activity) amount),
                last-active-block: stacks-block-height
            })
        )
        (map-set epoch-stats epoch
            (merge stats {
                deposits: (+ (get deposits stats) amount)
            })
        )
        (ok true)
    )
)

(define-public (record-withdrawal (user principal) (amount uint))
    (let
        (
            (epoch (var-get current-epoch))
            (activity (default-to
                { total-rebalances: u0, total-deposited: u0, total-withdrawn: u0, last-active-block: u0 }
                (map-get? user-activity user)
            ))
            (stats (default-to
                { rebalances: u0, deposits: u0, withdrawals: u0, start-block: stacks-block-height }
                (map-get? epoch-stats epoch)
            ))
        )
        (asserts! (> amount u0) err-zero-value)
        (var-set total-withdrawals (+ (var-get total-withdrawals) amount))
        (var-set total-value-locked (- (var-get total-value-locked) amount))
        (map-set user-activity user
            (merge activity {
                total-withdrawn: (+ (get total-withdrawn activity) amount),
                last-active-block: stacks-block-height
            })
        )
        (map-set epoch-stats epoch
            (merge stats {
                withdrawals: (+ (get withdrawals stats) amount)
            })
        )
        (ok true)
    )
)

(define-public (advance-epoch)
    (let
        (
            (epoch (var-get current-epoch))
            (stats (default-to
                { rebalances: u0, deposits: u0, withdrawals: u0, start-block: stacks-block-height }
                (map-get? epoch-stats epoch)
            ))
        )
        (asserts! (>= stacks-block-height (+ (get start-block stats) epoch-length)) err-owner-only)
        (let
            (
                (new-epoch (+ epoch u1))
            )
            (var-set current-epoch new-epoch)
            (map-set epoch-stats new-epoch {
                rebalances: u0,
                deposits: u0,
                withdrawals: u0,
                start-block: stacks-block-height
            })
            (ok new-epoch)
        )
    )
)
